using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;
using Microsoft.Win32;

namespace N8nTray
{
    internal class TrayContext : ApplicationContext
    {
        private const string AutoStartRegPath = @"Software\Microsoft\Windows\CurrentVersion\Run";
        private const string AutoStartValueName = "n8n";

        private readonly NotifyIcon _icon;
        private readonly ContextMenuStrip _menu;
        private readonly N8nProcess _n8n;
        private readonly ToolStripMenuItem _miOpen;
        private readonly ToolStripMenuItem _miStart;
        private readonly ToolStripMenuItem _miStop;
        private readonly ToolStripMenuItem _miUpdate;
        private readonly ToolStripMenuItem _miAutoStart;
        private readonly ToolStripMenuItem _miStatus;
        private CancellationTokenSource _backgroundCts = new CancellationTokenSource();

        public TrayContext(bool silent)
        {
            _n8n = new N8nProcess();
            _n8n.StateChanged += OnStateChanged;

            _menu = new ContextMenuStrip();
            _miStatus = new ToolStripMenuItem(Localization.T("Status.Idle")) { Enabled = false };
            _miOpen = new ToolStripMenuItem(Localization.T("Menu.Open"), null, (s, e) => OpenBrowser());
            _miStart = new ToolStripMenuItem(Localization.T("Menu.Start"), null, (s, e) => StartN8nAsync());
            _miStop = new ToolStripMenuItem(Localization.T("Menu.Stop"), null, (s, e) => StopN8n());
            _miUpdate = new ToolStripMenuItem(Localization.T("Menu.Update"), null, (s, e) => UpdateN8nAsync());
            var miLogs = new ToolStripMenuItem(Localization.T("Menu.Logs"), null, (s, e) => OpenLogs());
            var miData = new ToolStripMenuItem(Localization.T("Menu.DataFolder"), null, (s, e) => OpenDataFolder());
            _miAutoStart = new ToolStripMenuItem(Localization.T("Menu.AutoStart"), null, (s, e) => ToggleAutoStart());
            _miAutoStart.CheckOnClick = false;
            _miAutoStart.Checked = IsAutoStartEnabled();
            var miAbout = new ToolStripMenuItem(Localization.T("Menu.About"), null, (s, e) => ShowAbout());
            var miExit = new ToolStripMenuItem(Localization.T("Menu.Exit"), null, (s, e) => Quit());

            _menu.Items.Add(_miStatus);
            _menu.Items.Add(new ToolStripSeparator());
            _menu.Items.Add(_miOpen);
            _menu.Items.Add(_miStart);
            _menu.Items.Add(_miStop);
            _menu.Items.Add(new ToolStripSeparator());
            _menu.Items.Add(miLogs);
            _menu.Items.Add(_miUpdate);
            _menu.Items.Add(miData);
            _menu.Items.Add(_miAutoStart);
            _menu.Items.Add(new ToolStripSeparator());
            _menu.Items.Add(miAbout);
            _menu.Items.Add(miExit);

            _icon = new NotifyIcon
            {
                Icon = LoadIcon(),
                Visible = true,
                Text = "n8n",
                ContextMenuStrip = _menu,
            };
            _icon.DoubleClick += (s, e) => OpenBrowser();

            UpdateMenuState();

            // Start n8n automatically on launch
            StartN8nAsync();
        }

        private Icon LoadIcon()
        {
            try
            {
                var iconPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "icon.ico");
                if (File.Exists(iconPath))
                    return new Icon(iconPath);
            }
            catch { }
            return SystemIcons.Application;
        }

        private void OnStateChanged(N8nState state)
        {
            if (_menu.InvokeRequired)
            {
                _menu.BeginInvoke(new Action<N8nState>(OnStateChanged), state);
                return;
            }
            UpdateMenuState();
        }

        private void UpdateMenuState()
        {
            string statusText;
            switch (_n8n.State)
            {
                case N8nState.Idle:       statusText = Localization.T("Status.Idle"); break;
                case N8nState.Starting:   statusText = Localization.T("Status.Starting"); break;
                case N8nState.Installing: statusText = Localization.T("Status.Installing"); break;
                case N8nState.Running:    statusText = Localization.T("Status.Running", _n8n.Url); break;
                case N8nState.Stopping:   statusText = Localization.T("Status.Stopping"); break;
                case N8nState.Error:      statusText = Localization.T("Status.Error"); break;
                default:                  statusText = "n8n"; break;
            }
            _miStatus.Text = statusText;

            // Tray tooltip max length is 63 chars
            var tooltip = statusText;
            if (tooltip.Length > 60) tooltip = tooltip.Substring(0, 60) + "…";
            _icon.Text = tooltip;

            bool running = _n8n.State == N8nState.Running;
            bool busy = _n8n.State == N8nState.Starting || _n8n.State == N8nState.Installing || _n8n.State == N8nState.Stopping;
            _miOpen.Enabled = running;
            _miStart.Enabled = !running && !busy;
            _miStop.Enabled = running || _n8n.State == N8nState.Error;
            _miUpdate.Enabled = !busy;
        }

        private async void StartN8nAsync()
        {
            try
            {
                if (!_n8n.HasNodeBundle())
                {
                    MessageBox.Show(Localization.T("Error.NodeMissing"), "n8n", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    return;
                }

                if (!_n8n.IsN8nInstalled())
                {
                    var token = _backgroundCts.Token;
                    bool ok = await Task.Run(() => _n8n.RunFirstInstall(token));
                    if (!ok)
                    {
                        MessageBox.Show(Localization.T("Dialog.InstallFail", "see logs"), "n8n", MessageBoxButtons.OK, MessageBoxIcon.Error);
                        return;
                    }
                }

                _n8n.Start();

                // Open browser when ready
                _ = Task.Run(() =>
                {
                    bool ready = PortReadiness.WaitForListen(_n8n.Port, TimeSpan.FromSeconds(90), _backgroundCts.Token);
                    if (ready) OpenBrowser();
                });
            }
            catch (Exception ex)
            {
                MessageBox.Show("n8n 시작 중 오류:\n\n" + ex.Message, "n8n", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        private void StopN8n()
        {
            try { _n8n.Stop(); }
            catch (Exception ex)
            {
                MessageBox.Show("중지 중 오류: " + ex.Message, "n8n", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        private async void UpdateN8nAsync()
        {
            var wasRunning = _n8n.State == N8nState.Running;
            if (wasRunning) _n8n.Stop();

            var token = _backgroundCts.Token;
            bool ok = await Task.Run(() => _n8n.RunUpdate(token));
            if (!ok)
            {
                MessageBox.Show(Localization.T("Dialog.UpdateFail", "see logs"), "n8n", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
            if (wasRunning) _n8n.Start();
        }

        private void OpenBrowser()
        {
            try
            {
                var psi = new ProcessStartInfo
                {
                    FileName = _n8n.Url,
                    UseShellExecute = true,
                };
                Process.Start(psi);
            }
            catch (Exception ex)
            {
                MessageBox.Show("브라우저 열기 실패: " + ex.Message, "n8n", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        private void OpenLogs()
        {
            try
            {
                var path = _n8n.LatestLogPath;
                if (!File.Exists(path))
                {
                    Directory.CreateDirectory(_n8n.LogDir);
                    File.WriteAllText(path, "(아직 로그가 없습니다 / no logs yet)");
                }
                Process.Start("notepad.exe", "\"" + path + "\"");
            }
            catch (Exception ex)
            {
                MessageBox.Show("로그 열기 실패: " + ex.Message, "n8n");
            }
        }

        private void OpenDataFolder()
        {
            try
            {
                Directory.CreateDirectory(_n8n.UserDataDir);
                Process.Start("explorer.exe", "\"" + _n8n.UserDataDir + "\"");
            }
            catch (Exception ex)
            {
                MessageBox.Show("데이터 폴더 열기 실패: " + ex.Message, "n8n");
            }
        }

        private bool IsAutoStartEnabled()
        {
            try
            {
                using (var key = Registry.CurrentUser.OpenSubKey(AutoStartRegPath, false))
                {
                    if (key == null) return false;
                    return key.GetValue(AutoStartValueName) != null;
                }
            }
            catch { return false; }
        }

        private void ToggleAutoStart()
        {
            try
            {
                using (var key = Registry.CurrentUser.OpenSubKey(AutoStartRegPath, true))
                {
                    if (key == null) return;
                    if (IsAutoStartEnabled())
                    {
                        key.DeleteValue(AutoStartValueName, false);
                        _miAutoStart.Checked = false;
                    }
                    else
                    {
                        var exePath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "N8nTray.exe");
                        key.SetValue(AutoStartValueName, "\"" + exePath + "\" --silent");
                        _miAutoStart.Checked = true;
                    }
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show("자동 실행 설정 실패: " + ex.Message, "n8n");
            }
        }

        private void ShowAbout()
        {
            var trayVersion = typeof(TrayContext).Assembly.GetName().Version.ToString();
            string n8nVersion = "(설치되지 않음)";
            try
            {
                var pkgJson = Path.Combine(_n8n.InstallDir, "n8n-data", "node_modules", "n8n", "package.json");
                if (File.Exists(pkgJson))
                {
                    foreach (var line in File.ReadAllLines(pkgJson))
                    {
                        var trimmed = line.Trim();
                        if (trimmed.StartsWith("\"version\""))
                        {
                            int colon = trimmed.IndexOf(':');
                            if (colon > 0)
                            {
                                var rest = trimmed.Substring(colon + 1).Trim().TrimEnd(',').Trim('"');
                                n8nVersion = rest;
                                break;
                            }
                        }
                    }
                }
            }
            catch { }

            MessageBox.Show(Localization.T("Dialog.AboutBody", trayVersion, n8nVersion),
                            "n8n", MessageBoxButtons.OK, MessageBoxIcon.Information);
        }

        private void Quit()
        {
            try { _backgroundCts.Cancel(); } catch { }
            try { _n8n.Stop(); } catch { }
            _icon.Visible = false;
            _icon.Dispose();
            ExitThread();
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing)
            {
                try { _icon.Dispose(); } catch { }
                try { _menu.Dispose(); } catch { }
            }
            base.Dispose(disposing);
        }
    }
}
