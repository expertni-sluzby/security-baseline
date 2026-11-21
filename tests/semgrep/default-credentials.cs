// Fixture of rules/semgrep/default-credentials.yml (semgrep --test). The passwords are public framework defaults.
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using Volo.Abp.Identity;

public class OpenIddictDataSeedContributor
{
    // ruleid: framework-default-password-literal
    private const string defaultAbpPassword = "1q2w3e*";
    // ruleid: framework-default-password-literal
    private static readonly string AdminDefault = "1q2w3E*";
    // ok: framework-default-password-literal
    private const string NotADefault = "1q2w3e*x";
    // ASP.NET Boilerplate's default is a common password too: as a literal it is no finding (password dictionaries).
    // ok: framework-default-password-literal
    private static readonly string[] CommonPasswords = { "123456", "123qwe", "qwerty" };

    private readonly IConfiguration _configuration;
    private readonly IHostEnvironment _hostEnvironment;

    public void Seed(DataSeedContext context)
    {
        // ruleid: framework-default-password-fallback
        var clientSecret = _configuration["OpenIddict:Applications:MyProjectName_App:ClientSecret"] ?? defaultAbpPassword;

        // ruleid: framework-default-password-fallback
        var a = _configuration["App:ClientSecret"] ?? "1q2w3e*";

        // ruleid: framework-default-password-fallback
        var b = _configuration["App:AdminPassword"] ?? AdminDefault;

        // ruleid: framework-default-password-fallback
        var c = context["AdminPassword"] as string ?? IdentityDataSeedContributor.AdminPasswordDefaultValue;

        // ruleid: framework-default-password-fallback
        var d = _configuration.GetValue("App:ClientSecret", defaultAbpPassword);

        // ruleid: framework-default-password-fallback
        var e = _configuration.GetValue<string>("App:ClientSecret", defaultAbpPassword);

        var f = _configuration["App:ClientSecret"];
        // ruleid: framework-default-password-fallback
        f ??= defaultAbpPassword;

        var g = _configuration["App:ClientSecret"];
        // ruleid: framework-default-password-fallback
        var h = string.IsNullOrEmpty(g) ? defaultAbpPassword : g;

        // A constant from another file, named as a default password.
        // ruleid: framework-default-password-fallback
        var i = eventData.Properties.GetOrDefault("AdminPassword") ?? MyProjectNameDbProperties.DefaultAdminPassword;

        // ASP.NET Boilerplate
        // ruleid: framework-default-password-fallback
        var j = _configuration["App:DefaultPassword"] ?? "123qwe";
    }

    public void Guarded(bool allowDefault)
    {
        var isDevelopment = _hostEnvironment.IsDevelopment();

        if (_hostEnvironment.IsDevelopment())
        {
            // ok: framework-default-password-fallback
            var a = _configuration["App:ClientSecret"] ?? defaultAbpPassword;
            // ok: framework-default-password-literal
            var b = _configuration["App:Other"] ?? "1q2w3e*";
        }

        if (isDevelopment && allowDefault)
        {
            // ok: framework-default-password-fallback
            var c = _configuration["App:ClientSecret"] ?? defaultAbpPassword;
        }

        if (_hostEnvironment.IsEnvironment("Development"))
        {
            // ok: framework-default-password-fallback
            var d = _configuration["App:ClientSecret"] ?? defaultAbpPassword;
        }

        var secret = _configuration["App:ClientSecret"];
        if (string.IsNullOrWhiteSpace(secret))
        {
            // ok: framework-default-password-fallback
            secret = allowDefault && isDevelopment ? defaultAbpPassword : null;
        }

        // ok: framework-default-password-fallback
        var e = _hostEnvironment.IsDevelopment() ? _configuration["App:ClientSecret"] ?? defaultAbpPassword : _configuration["App:ClientSecret"];
    }

    public bool Detection(string secret)
    {
        // ok: framework-default-password-fallback
        var refused = !_hostEnvironment.IsDevelopment() && secret == defaultAbpPassword;
        // ok: framework-default-password-literal
        var literal = secret == "1q2w3e*";
        // ok: framework-default-password-fallback
        var other = _configuration["App:Title"] ?? "Admin";
        // ok: framework-default-password-fallback
        var length = _configuration.GetValue("App:MinPasswordLength", DefaultPasswordLength);
        return refused || literal;
    }
}
