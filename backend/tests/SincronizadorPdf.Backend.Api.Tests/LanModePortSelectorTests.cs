using System.Net;
using System.Net.Sockets;

namespace SincronizadorPdf.Backend.Api.Tests;

public class LanModePortSelectorTests
{
    [Fact]
    public void SelectPort_ReturnsPreferredPort_WhenFree()
    {
        var port = LanModePortSelector.SelectPort(12345, isPortFree: _ => true);

        Assert.Equal(12345, port);
    }

    [Fact]
    public void SelectPort_FallsBackToFreeSystemPort_WhenPreferredIsTaken()
    {
        var port = LanModePortSelector.SelectPort(12345, isPortFree: _ => false);

        Assert.NotEqual(12345, port);
        Assert.InRange(port, 1, 65535);
    }

    [Fact]
    public void SelectPort_FindsAnActuallyFreePort_WhenPreferredPortIsOccupied()
    {
        using var occupyingListener = new TcpListener(IPAddress.Loopback, 0);
        occupyingListener.Start();
        var occupiedPort = ((IPEndPoint)occupyingListener.LocalEndpoint).Port;

        var port = LanModePortSelector.SelectPort(occupiedPort);

        Assert.NotEqual(occupiedPort, port);
    }

    [Fact]
    public void SelectPort_ReturnsTheSamePreferredPort_WhenItIsActuallyFree()
    {
        // Usa uma porta já conhecida como ocupada e liberada para reduzir a
        // (pequena) chance de colisão com outro processo na máquina de CI.
        using var listener = new TcpListener(IPAddress.Loopback, 0);
        listener.Start();
        var preferredPort = ((IPEndPoint)listener.LocalEndpoint).Port;
        listener.Stop();

        var port = LanModePortSelector.SelectPort(preferredPort);

        Assert.Equal(preferredPort, port);
    }
}
