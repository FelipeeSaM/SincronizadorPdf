using System.Net;
using System.Net.Sockets;

namespace SincronizadorPdf.Backend.Api;

/// <summary>
/// Port selection for LAN mode (see #24): the Backend runs as a short-lived
/// child process of the desktop app, so it needs to fall back to a free
/// OS-assigned port whenever the fixed default one is already taken (e.g. a
/// previous instance still shutting down).
/// </summary>
public static class LanModePortSelector
{
    public const int DefaultPort = 5119;

    public static int SelectPort(int preferredPort = DefaultPort, Func<int, bool>? isPortFree = null)
    {
        isPortFree ??= IsPortFree;
        return isPortFree(preferredPort) ? preferredPort : FindFreeSystemPort();
    }

    private static bool IsPortFree(int port)
    {
        try
        {
            using var listener = new TcpListener(IPAddress.Any, port);
            listener.Start();
            return true;
        }
        catch (SocketException)
        {
            return false;
        }
    }

    private static int FindFreeSystemPort()
    {
        using var listener = new TcpListener(IPAddress.Loopback, 0);
        listener.Start();
        return ((IPEndPoint)listener.LocalEndpoint).Port;
    }
}
