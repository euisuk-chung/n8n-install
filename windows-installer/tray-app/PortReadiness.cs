using System;
using System.Net.Sockets;
using System.Threading;

namespace N8nTray
{
    internal static class PortReadiness
    {
        /// Returns true once a TCP listener accepts a connection on 127.0.0.1:port,
        /// or false if the timeout elapses or cancellation is requested.
        public static bool WaitForListen(int port, TimeSpan timeout, CancellationToken token)
        {
            var deadline = DateTime.UtcNow + timeout;
            while (DateTime.UtcNow < deadline && !token.IsCancellationRequested)
            {
                if (IsListening(port))
                    return true;
                Thread.Sleep(250);
            }
            return false;
        }

        public static bool IsListening(int port)
        {
            try
            {
                using (var client = new TcpClient())
                {
                    var result = client.BeginConnect("127.0.0.1", port, null, null);
                    bool success = result.AsyncWaitHandle.WaitOne(TimeSpan.FromMilliseconds(200));
                    if (!success)
                        return false;
                    client.EndConnect(result);
                    return true;
                }
            }
            catch
            {
                return false;
            }
        }

        public static bool IsPortFree(int port)
        {
            return !IsListening(port);
        }

        public static int FindFreePort(int start, int max)
        {
            for (int p = start; p <= max; p++)
            {
                if (IsPortFree(p)) return p;
            }
            return -1;
        }
    }
}
