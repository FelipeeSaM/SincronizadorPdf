using Makaretu.Dns;

namespace SincronizadorPdf.Backend.Api.Tests;

public class MdnsAnnouncerTests
{
    [Fact]
    public void CreateServiceProfile_UsesTheSincPdfServiceType()
    {
        var profile = MdnsAnnouncer.CreateServiceProfile(5119, "device-abc");

        Assert.Equal(MdnsAnnouncer.ServiceType, profile.ServiceName.ToString());
    }

    [Fact]
    public void CreateServiceProfile_AnnouncesTheEffectivePort()
    {
        var profile = MdnsAnnouncer.CreateServiceProfile(53427, "device-abc");

        var srv = Assert.Single(profile.Resources.OfType<SRVRecord>());
        Assert.Equal(53427, srv.Port);
    }

    [Fact]
    public void CreateServiceProfile_IncludesDeviceIdInTheTxtRecord()
    {
        var profile = MdnsAnnouncer.CreateServiceProfile(5119, "device-abc");

        var txt = Assert.Single(profile.Resources.OfType<TXTRecord>());
        Assert.Contains("dispositivoId=device-abc", txt.Strings);
    }

    [Fact]
    public void CreateServiceProfile_UsesADifferentPort_WhenTheDefaultPortWasOccupied()
    {
        // Ver #25: a porta anunciada precisa ser sempre a efetiva, incluindo
        // quando LanModePortSelector escolheu uma porta livre diferente da
        // padrão porque esta estava ocupada.
        var profileComPortaPadrao = MdnsAnnouncer.CreateServiceProfile(LanModePortSelector.DefaultPort, "device-abc");
        var profileComPortaDeFallback = MdnsAnnouncer.CreateServiceProfile(53427, "device-abc");

        var srvPadrao = Assert.Single(profileComPortaPadrao.Resources.OfType<SRVRecord>());
        var srvFallback = Assert.Single(profileComPortaDeFallback.Resources.OfType<SRVRecord>());
        Assert.NotEqual(srvPadrao.Port, srvFallback.Port);
        Assert.Equal(53427, srvFallback.Port);
    }
}
