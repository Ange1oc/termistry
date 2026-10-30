// Подсказки из истории PSReadLine без встроенного лимита в 10 строк.
// Встроенный источник History жёстко ограничен 10 записями, а плагины получают
// до 50 — список показывает 10 строк и листается стрелками.
// Компилируется профилем в ~/.cache/pwsh-predictor при изменении этого файла.

using System;
using System.Collections.Generic;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using System.Management.Automation.Subsystem;
using System.Management.Automation.Subsystem.Prediction;

public sealed class DeepHistoryPredictor : ICommandPredictor
{
    public static readonly Guid PredictorId = new Guid("6f0c5a4e-2b7d-4c1e-9a3f-1d8e5b7c2a90");

    private readonly string _path;
    private readonly int _max;
    private volatile string[] _entries = Array.Empty<string>();   // новые первыми, без дублей
    private long _loadedLength = -1;
    private int _loading;

    public DeepHistoryPredictor(string historyPath, int maxCount)
    {
        _path = historyPath;
        _max = maxCount;
        Reload();
    }

    public Guid Id => PredictorId;
    public string Name => "History";
    public string Description => "History suggestions without the 10-item limit";
    Dictionary<string, string> ISubsystem.FunctionsToDefine => null;

    public SuggestionPackage GetSuggestion(PredictionClient client, PredictionContext context, CancellationToken cancellationToken)
    {
        string input = context.InputAst.Extent.Text;
        if (string.IsNullOrWhiteSpace(input)) return default;
        RefreshIfChanged();

        var entries = _entries;
        var result = new List<PredictiveSuggestion>();
        // сначала команды, которые начинаются с набранного, потом — где оно встречается внутри
        foreach (var e in entries)
        {
            if (e.Length > input.Length && e.StartsWith(input, StringComparison.OrdinalIgnoreCase))
            {
                result.Add(new PredictiveSuggestion(e));
                if (result.Count == _max) break;
            }
        }
        if (result.Count < _max)
        {
            foreach (var e in entries)
            {
                if (e.IndexOf(input, 1, StringComparison.OrdinalIgnoreCase) > 0 && !e.StartsWith(input, StringComparison.OrdinalIgnoreCase))
                {
                    result.Add(new PredictiveSuggestion(e));
                    if (result.Count == _max) break;
                }
            }
        }
        return result.Count == 0 ? default : new SuggestionPackage(result);
    }

    // PSReadLine ждёт плагин ~20 мс, поэтому файл перечитывается в фоне
    private void RefreshIfChanged()
    {
        long length;
        try { length = new FileInfo(_path).Length; } catch { return; }
        if (length == Interlocked.Read(ref _loadedLength)) return;
        if (Interlocked.CompareExchange(ref _loading, 1, 0) != 0) return;
        Task.Run(() => { try { Reload(); } finally { Volatile.Write(ref _loading, 0); } });
    }

    private void Reload()
    {
        if (!File.Exists(_path)) return;
        long length = new FileInfo(_path).Length;
        var lines = new List<string>();
        using (var fs = new FileStream(_path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete))
        using (var reader = new StreamReader(fs))
        {
            // многострочные команды хранятся строками с ` на конце — их пропускаем целиком
            bool continuation = false;
            string line;
            while ((line = reader.ReadLine()) != null)
            {
                bool endsWithTick = line.EndsWith("`");
                if (!continuation && !endsWithTick) lines.Add(line);
                continuation = endsWithTick;
            }
        }

        var seen = new HashSet<string>(StringComparer.Ordinal);
        var result = new List<string>(lines.Count);
        for (int i = lines.Count - 1; i >= 0; i--)
        {
            string t = lines[i].Trim();
            if (t.Length > 0 && seen.Add(t)) result.Add(t);
        }
        _entries = result.ToArray();
        Interlocked.Exchange(ref _loadedLength, length);
    }

    public bool CanAcceptFeedback(PredictionClient client, PredictorFeedbackKind feedback) => false;
    public void OnSuggestionDisplayed(PredictionClient client, uint session, int countOrIndex) { }
    public void OnSuggestionAccepted(PredictionClient client, uint session, string acceptedSuggestion) { }
    public void OnCommandLineAccepted(PredictionClient client, IReadOnlyList<string> history) { }
    public void OnCommandLineExecuted(PredictionClient client, string commandLine, bool success) { }
}
