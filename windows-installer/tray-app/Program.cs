using System;
using System.Threading;
using System.Windows.Forms;

namespace N8nTray
{
    internal static class Program
    {
        private const string MutexName = "Global\\N8nTraySingleInstance";

        [STAThread]
        private static void Main(string[] args)
        {
            bool createdNew;
            using (var mutex = new Mutex(true, MutexName, out createdNew))
            {
                if (!createdNew)
                {
                    // Another instance is already running. Exit silently.
                    return;
                }

                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);

                bool silent = false;
                foreach (var a in args)
                {
                    if (string.Equals(a, "--silent", StringComparison.OrdinalIgnoreCase))
                        silent = true;
                }

                try
                {
                    Application.Run(new TrayContext(silent));
                }
                catch (Exception ex)
                {
                    MessageBox.Show(
                        "n8n 트레이가 예기치 않게 종료되었습니다.\n\n" + ex.ToString(),
                        "n8n",
                        MessageBoxButtons.OK,
                        MessageBoxIcon.Error);
                }
            }
        }
    }
}
