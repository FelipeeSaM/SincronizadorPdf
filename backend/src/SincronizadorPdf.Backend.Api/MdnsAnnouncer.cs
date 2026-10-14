using Makaretu.Dns;

namespace SincronizadorPdf.Backend.Api;

/// <summary>
/// Anuncia o Backend de Sincronização na rede local via mDNS/DNS-SD (ver
/// #25), para o celular descobrir o PC sem digitar IP/porta manualmente.
/// Só faz sentido em modo LAN (ver #24), já que é aí que o Backend tem uma
/// porta de rede local efetiva para anunciar.
/// </summary>
public sealed class MdnsAnnouncer : IDisposable
{
    public const string ServiceType = "_sincpdf._tcp";

    private readonly MulticastService _mdns;
    private readonly ServiceDiscovery _serviceDiscovery;
    private readonly ServiceProfile _profile;

    public MdnsAnnouncer(int port, string deviceId)
    {
        _profile = CreateServiceProfile(port, deviceId);

        _mdns = new MulticastService();
        _serviceDiscovery = new ServiceDiscovery(_mdns);

        // Reanuncia quando uma interface de rede é descoberta (ex: Wi-Fi
        // reconectou depois do anúncio inicial) — sem isso, um Dispositivo
        // numa rede que só ficou disponível após o início do Backend nunca
        // veria o anúncio (ver #25). O try/catch evita que uma falha nesse
        // reanúncio best-effort (ex: interface caiu de novo entre o evento
        // e o Announce) derrube o Backend que já está rodando.
        _mdns.NetworkInterfaceDiscovered += (_, _) =>
        {
            try
            {
                _serviceDiscovery.Announce(_profile);
            }
            catch (Exception)
            {
            }
        };

        _serviceDiscovery.Advertise(_profile);
        _mdns.Start();
    }

    /// <summary>
    /// Monta o <see cref="ServiceProfile"/> anunciado: tipo de serviço fixo
    /// <see cref="ServiceType"/>, a porta efetiva recebida (já resolvida
    /// pelo <see cref="LanModePortSelector"/> antes de chegar aqui — nunca
    /// a porta padrão fixa, caso ela estivesse ocupada e o SO tenha
    /// escolhido outra) e o dispositivoId do PC (já existe via
    /// `DeviceIdStore` no app desktop) no TXT record, para o celular
    /// desambiguar entre múltiplos backends SincronizadorPdf na mesma rede.
    /// </summary>
    public static ServiceProfile CreateServiceProfile(int port, string deviceId)
    {
        var profile = new ServiceProfile(System.Net.Dns.GetHostName(), ServiceType, (ushort)port);
        profile.AddProperty("dispositivoId", deviceId);
        return profile;
    }

    public void Dispose()
    {
        _serviceDiscovery.Unadvertise(_profile);
        _serviceDiscovery.Dispose();
        _mdns.Dispose();
    }
}
