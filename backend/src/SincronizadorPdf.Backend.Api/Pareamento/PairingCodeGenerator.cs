using System.Security.Cryptography;

namespace SincronizadorPdf.Backend.Api.Pareamento;

public static class PairingCodeGenerator
{
    // Exclui O/0, I/1/L para reduzir ambiguidade visual ao digitar manualmente.
    private const string Alphabet = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
    private const int Length = 8;

    public static string Generate()
    {
        var buffer = new char[Length];
        for (var i = 0; i < Length; i++)
        {
            buffer[i] = Alphabet[RandomNumberGenerator.GetInt32(Alphabet.Length)];
        }

        return new string(buffer);
    }
}
