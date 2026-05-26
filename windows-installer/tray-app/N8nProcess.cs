using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace N8nTray
{
    internal enum N8nState
    {
        Idle,
        Installing,
        Starting,
        Running,
        Stopping,
        Error,
    }

    internal class N8nProcess
    {
        public event Action<N8nState> StateChanged;
        public event Action<string> LogLine;

        private readonly string _installDir;
        private readonly string _userDataDir;
        private readonly string _logDir;
        private Process _proc;
        private StreamWriter _logWriter;
        private readonly object _lock = new object();

        public N8nState State { get; private set; } = N8nState.Idle;
        public int Port { get; private set; } = 5678;
        // n8n spawns an internal task broker (default port 5679). When the editor
        // is forced off 5678 by a port conflict, both end up wanting 5679 and the
        // runner connection 403s. We allocate a distinct free port for the broker
        // and expose it here for the About dialog / debugging.
        public int BrokerPort { get; private set; } = 5679;
        public string Url
        {
            get { return "http://localhost:" + Port; }
        }

        public string InstallDir { get { return _installDir; } }
        public string UserDataDir { get { return _userDataDir; } }
        public string LogDir { get { return _logDir; } }
        public string LatestLogPath
        {
            get { return Path.Combine(_logDir, "latest.log"); }
        }

        public string BootstrapLogPath
        {
            get { return Path.Combine(_logDir, "bootstrap.log"); }
        }

        public N8nProcess()
        {
            _installDir = AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\');
            _userDataDir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
                ".n8n");
            _logDir = Path.Combine(_userDataDir, "logs");
            Directory.CreateDirectory(_logDir);
        }

        public bool IsN8nInstalled()
        {
            var binPath = Path.Combine(_installDir, "n8n-data", "node_modules", "n8n", "bin", "n8n");
            return File.Exists(binPath);
        }

        public string NodeExe
        {
            get { return Path.Combine(_installDir, "node", "node.exe"); }
        }

        public string NpmCmd
        {
            get { return Path.Combine(_installDir, "node", "npm.cmd"); }
        }

        public bool HasNodeBundle()
        {
            return File.Exists(NodeExe);
        }

        /// Runs first-run install (npm install n8n) synchronously, returns true on success.
        /// Opens a visible PowerShell console window so the user can watch npm progress;
        /// the same output is mirrored to bootstrap.log by the script. Always resets
        /// the state on exit so the tray menu reflects reality even when install fails.
        public bool RunFirstInstall(CancellationToken token)
        {
            SetState(N8nState.Installing);
            var scriptPath = Path.Combine(_installDir, "bootstrap", "first-run-install.ps1");
            try
            {
                var ok = RunPowerShellVisible(scriptPath, "-InstallDir \"" + _installDir + "\"", token);
                // Re-check disk in case the install partially succeeded and bin/n8n
                // is now present despite a non-zero exit (the postinstall telemetry
                // check can fail even when every package was placed correctly).
                if (!ok && IsN8nInstalled()) ok = true;
                SetState(ok ? N8nState.Idle : N8nState.Error);
                return ok;
            }
            catch
            {
                SetState(N8nState.Error);
                throw;
            }
        }

        public bool RunUpdate(CancellationToken token)
        {
            var scriptPath = Path.Combine(_installDir, "bootstrap", "update-n8n.ps1");
            return RunPowerShellVisible(scriptPath, "-InstallDir \"" + _installDir + "\"", token);
        }

        // Opens a real console window for the script. Output goes to the visible console;
        // the bootstrap script itself uses Tee-Object to ALSO write to bootstrap.log,
        // so the file mirror is preserved even though we don't redirect stdout here.
        private bool RunPowerShellVisible(string scriptPath, string args, CancellationToken token)
        {
            // Reset bootstrap.log with a session header so the file starts clean and the
            // user can correlate console output with what's saved on disk.
            try
            {
                Directory.CreateDirectory(_logDir);
                using (var w = new StreamWriter(
                    new FileStream(BootstrapLogPath, FileMode.Create, FileAccess.Write, FileShare.Read),
                    Encoding.UTF8))
                {
                    w.WriteLine("=== bootstrap " + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + " ===");
                    w.WriteLine("Script: " + scriptPath);
                    w.WriteLine("Args  : " + args);
                    w.WriteLine("A console window has been opened; this file mirrors the same output.");
                    w.WriteLine("--");
                }
            }
            catch { /* losing the log file is non-fatal */ }

            try
            {
                var psi = new ProcessStartInfo
                {
                    FileName = "powershell.exe",
                    Arguments = "-NoProfile -ExecutionPolicy Bypass -File \"" + scriptPath + "\" " + args,
                    UseShellExecute = false,
                    CreateNoWindow = false,
                    WindowStyle = ProcessWindowStyle.Normal,
                    WorkingDirectory = _installDir,
                };
                using (var p = Process.Start(psi))
                {
                    while (!p.HasExited)
                    {
                        if (token.IsCancellationRequested)
                        {
                            try { p.Kill(); } catch { }
                            return false;
                        }
                        Thread.Sleep(200);
                    }
                    return p.ExitCode == 0;
                }
            }
            catch (Exception ex)
            {
                EmitLog("[FATAL] " + ex.Message);
                return false;
            }
        }

        private bool RunPowerShell(string scriptPath, string args, CancellationToken token)
        {
            StreamWriter bootstrapLog = null;
            try
            {
                try
                {
                    Directory.CreateDirectory(_logDir);
                    bootstrapLog = new StreamWriter(
                        new FileStream(BootstrapLogPath, FileMode.Create, FileAccess.Write, FileShare.Read),
                        Encoding.UTF8);
                    bootstrapLog.AutoFlush = true;
                    bootstrapLog.WriteLine("=== bootstrap " + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + " ===");
                    bootstrapLog.WriteLine("Script: " + scriptPath);
                    bootstrapLog.WriteLine("Args  : " + args);
                    bootstrapLog.WriteLine("--");
                }
                catch { /* fallthrough — losing the log file is non-fatal */ }

                var psi = new ProcessStartInfo
                {
                    FileName = "powershell.exe",
                    Arguments = "-NoProfile -ExecutionPolicy Bypass -File \"" + scriptPath + "\" " + args,
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    CreateNoWindow = true,
                    WorkingDirectory = _installDir,
                };
                using (var p = Process.Start(psi))
                {
                    var log = bootstrapLog;
                    p.OutputDataReceived += (s, e) =>
                    {
                        if (e.Data == null) return;
                        EmitLog(e.Data);
                        try { if (log != null) log.WriteLine(e.Data); } catch { }
                    };
                    p.ErrorDataReceived += (s, e) =>
                    {
                        if (e.Data == null) return;
                        var line = "[ERR] " + e.Data;
                        EmitLog(line);
                        try { if (log != null) log.WriteLine(line); } catch { }
                    };
                    p.BeginOutputReadLine();
                    p.BeginErrorReadLine();

                    while (!p.HasExited)
                    {
                        if (token.IsCancellationRequested)
                        {
                            try { p.Kill(); } catch { }
                            return false;
                        }
                        Thread.Sleep(200);
                    }
                    if (bootstrapLog != null)
                        bootstrapLog.WriteLine("-- exit code: " + p.ExitCode);
                    return p.ExitCode == 0;
                }
            }
            catch (Exception ex)
            {
                EmitLog("[FATAL] " + ex.Message);
                try { if (bootstrapLog != null) bootstrapLog.WriteLine("[FATAL] " + ex); } catch { }
                return false;
            }
            finally
            {
                try { if (bootstrapLog != null) bootstrapLog.Dispose(); } catch { }
            }
        }

        /// Starts n8n. Allocates port, sets env, spawns node.exe, polls port,
        /// returns when port responds (or throws).
        public void Start()
        {
            lock (_lock)
            {
                if (_proc != null && !_proc.HasExited)
                    return;
                if (!HasNodeBundle())
                    throw new InvalidOperationException(Localization.T("Error.NodeMissing"));

                SetState(N8nState.Starting);

                // Allocate two distinct free ports: one for the editor (HTTP) and
                // one for n8n's internal task broker. Searching from 5678/5679 keeps
                // the default-ish behavior whenever possible.
                int editorPort = PortReadiness.FindFreePort(5678, 5687);
                if (editorPort < 0) editorPort = 5678;
                int brokerPort = PortReadiness.FindFreePort(editorPort + 1, 5697);
                if (brokerPort < 0 || brokerPort == editorPort) brokerPort = editorPort + 1;
                Port = editorPort;
                BrokerPort = brokerPort;

                OpenLogFile();

                var n8nBin = Path.Combine(_installDir, "n8n-data", "node_modules", "n8n", "bin", "n8n");
                var psi = new ProcessStartInfo
                {
                    FileName = NodeExe,
                    Arguments = "\"" + n8nBin + "\" start",
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    CreateNoWindow = true,
                    WorkingDirectory = _installDir,
                };
                psi.EnvironmentVariables["N8N_USER_FOLDER"] = _userDataDir;
                psi.EnvironmentVariables["N8N_PORT"] = Port.ToString();
                psi.EnvironmentVariables["N8N_RUNNERS_TASK_BROKER_PORT"] = BrokerPort.ToString();
                // Give the n8n runtime a 4GB old-space heap. The default ~1.5GB is
                // borderline for n8n's process — running multiple workflows can push
                // it over the edge — and we already need this much for the install
                // step anyway (see Invoke-Npm in helpers.ps1).
                psi.EnvironmentVariables["NODE_OPTIONS"] = "--max-old-space-size=4096";
                // Prepend bundled node dir to PATH so spawned children find npm/npx
                var existingPath = psi.EnvironmentVariables.ContainsKey("PATH")
                    ? psi.EnvironmentVariables["PATH"]
                    : Environment.GetEnvironmentVariable("PATH");
                psi.EnvironmentVariables["PATH"] = Path.Combine(_installDir, "node") + ";" + existingPath;

                _proc = new Process { StartInfo = psi, EnableRaisingEvents = true };
                _proc.OutputDataReceived += (s, e) => { if (e.Data != null) WriteLog(e.Data); };
                _proc.ErrorDataReceived += (s, e) => { if (e.Data != null) WriteLog("[ERR] " + e.Data); };
                _proc.Exited += OnProcessExited;
                _proc.Start();
                _proc.BeginOutputReadLine();
                _proc.BeginErrorReadLine();
            }

            // Wait for port outside the lock so we don't block other operations
            Task.Run(() =>
            {
                bool ready = PortReadiness.WaitForListen(Port, TimeSpan.FromSeconds(90), CancellationToken.None);
                if (ready)
                {
                    SetState(N8nState.Running);
                }
                else if (_proc != null && !_proc.HasExited)
                {
                    // Process is up but no port — treat as error-ish but keep process running
                    SetState(N8nState.Error);
                }
            });
        }

        public void Stop()
        {
            lock (_lock)
            {
                if (_proc == null || _proc.HasExited)
                {
                    SetState(N8nState.Idle);
                    return;
                }
                SetState(N8nState.Stopping);
                try
                {
                    _proc.Kill();
                    _proc.WaitForExit(5000);
                }
                catch { }
                CloseLogFile();
                _proc = null;
                SetState(N8nState.Idle);
            }
        }

        public void Restart()
        {
            Stop();
            Thread.Sleep(500);
            Start();
        }

        private void OnProcessExited(object sender, EventArgs e)
        {
            if (State == N8nState.Stopping || State == N8nState.Idle)
                return;
            SetState(N8nState.Error);
            CloseLogFile();
        }

        private void OpenLogFile()
        {
            try
            {
                CloseLogFile();
                var path = LatestLogPath;
                _logWriter = new StreamWriter(new FileStream(path, FileMode.Create, FileAccess.Write, FileShare.Read), Encoding.UTF8);
                _logWriter.AutoFlush = true;
                _logWriter.WriteLine("=== n8n session started " + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + " ===");
                _logWriter.WriteLine("Editor port: " + Port);
                _logWriter.WriteLine("Broker port: " + BrokerPort);
                _logWriter.WriteLine("InstallDir: " + _installDir);
                _logWriter.WriteLine("UserDataDir: " + _userDataDir);
                _logWriter.WriteLine("--");
            }
            catch { }
        }

        private void CloseLogFile()
        {
            try
            {
                if (_logWriter != null)
                {
                    _logWriter.Flush();
                    _logWriter.Dispose();
                    _logWriter = null;
                }
            }
            catch { }
        }

        private void WriteLog(string line)
        {
            EmitLog(line);
            try
            {
                if (_logWriter != null)
                    _logWriter.WriteLine(line);
            }
            catch { }
        }

        private void EmitLog(string line)
        {
            var handler = LogLine;
            if (handler != null) handler(line);
        }

        private void SetState(N8nState s)
        {
            State = s;
            var handler = StateChanged;
            if (handler != null) handler(s);
        }
    }
}
