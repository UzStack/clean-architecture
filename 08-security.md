# Security Best Practices - Xavfsizlik Asoslari

Security - bu ixtiyoriy narsa emas, zaruriyat!

---

## OWASP Top 10 (2023)

### 1. Broken Access Control

**Muammo:** Foydalanuvchi o'z huquqidan tashqari ma'lumotlarga kiradi

```csharp
// ❌ Yomon - Hech qanday tekshiruv yo'q
[HttpGet("{id}")]
public async Task<Order> GetOrder(int id)
{
    return await _orderRepository.GetAsync(id);
    // Har kim har qanday order'ni ko'ra oladi!
}

// ✅ Yaxshi - Authorization check
[HttpGet("{id}")]
[Authorize]
public async Task<IActionResult> GetOrder(int id)
{
    var userId = User.GetUserId();
    var order = await _orderRepository.GetAsync(id);
    
    if (order.UserId != userId && !User.IsInRole("Admin"))
    {
        return Forbid();
    }
    
    return Ok(order);
}

// ✅ Eng yaxshi - Policy-based authorization
[HttpGet("{id}")]
[Authorize(Policy = "OrderOwner")]
public async Task<Order> GetOrder(int id)
{
    return await _orderRepository.GetAsync(id);
}

// Policy configuration
public class OrderOwnerRequirement : IAuthorizationRequirement
{
    public class Handler : AuthorizationHandler<OrderOwnerRequirement>
    {
        private readonly IOrderRepository _repository;
        
        protected override async Task HandleRequirementAsync(
            AuthorizationHandlerContext context,
            OrderOwnerRequirement requirement)
        {
            var userId = context.User.GetUserId();
            var orderId = context.Resource as int?;
            
            if (orderId.HasValue)
            {
                var order = await _repository.GetAsync(orderId.Value);
                
                if (order.UserId == userId || context.User.IsInRole("Admin"))
                {
                    context.Succeed(requirement);
                }
            }
        }
    }
}
```

---

### 2. Cryptographic Failures

**Muammo:** Parol va sensitive data ochiq saqlanadi

```csharp
// ❌ Yomon - Plain text password
public class User
{
    public string Password { get; set; } // "password123"
}

// ✅ Yaxshi - Hashed password
public class UserService
{
    public async Task<User> CreateUserAsync(string email, string password)
    {
        var user = new User
        {
            Email = email,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(password),
            Salt = BCrypt.Net.BCrypt.GenerateSalt()
        };
        
        await _repository.AddAsync(user);
        return user;
    }
    
    public bool VerifyPassword(User user, string password)
    {
        return BCrypt.Net.BCrypt.Verify(password, user.PasswordHash);
    }
}

// Encryption for sensitive data
public class EncryptionService
{
    private readonly byte[] _key;
    private readonly byte[] _iv;
    
    public string Encrypt(string plainText)
    {
        using var aes = Aes.Create();
        aes.Key = _key;
        aes.IV = _iv;
        
        using var encryptor = aes.CreateEncryptor();
        using var ms = new MemoryStream();
        using var cs = new CryptoStream(ms, encryptor, CryptoStreamMode.Write);
        using var sw = new StreamWriter(cs);
        
        sw.Write(plainText);
        sw.Close();
        
        return Convert.ToBase64String(ms.ToArray());
    }
    
    public string Decrypt(string cipherText)
    {
        using var aes = Aes.Create();
        aes.Key = _key;
        aes.IV = _iv;
        
        using var decryptor = aes.CreateDecryptor();
        using var ms = new MemoryStream(Convert.FromBase64String(cipherText));
        using var cs = new CryptoStream(ms, decryptor, CryptoStreamMode.Read);
        using var sr = new StreamReader(cs);
        
        return sr.ReadToEnd();
    }
}

// Usage
public class CreditCardService
{
    private readonly EncryptionService _encryption;
    
    public async Task SaveCreditCardAsync(string cardNumber)
    {
        var encrypted = _encryption.Encrypt(cardNumber);
        await _repository.SaveAsync(new CreditCard
        {
            EncryptedNumber = encrypted
        });
    }
}
```

---

### 3. Injection Attacks

**SQL Injection:**

```csharp
// ❌ Yomon - SQL Injection
public async Task<User> GetUserAsync(string username)
{
    var sql = $"SELECT * FROM Users WHERE Username = '{username}'";
    return await _connection.QueryFirstAsync<User>(sql);
    // Input: "admin' OR '1'='1" → Hamma user'larni qaytaradi!
}

// ✅ Yaxshi - Parameterized query
public async Task<User> GetUserAsync(string username)
{
    var sql = "SELECT * FROM Users WHERE Username = @Username";
    return await _connection.QueryFirstAsync<User>(sql, new { Username = username });
}

// ✅ Eng yaxshi - ORM (EF Core)
public async Task<User> GetUserAsync(string username)
{
    return await _context.Users
        .FirstOrDefaultAsync(u => u.Username == username);
}
```

**Command Injection:**

```csharp
// ❌ Yomon - Command Injection
public string RunCommand(string filename)
{
    var process = Process.Start("cmd.exe", $"/c type {filename}");
    // Input: "file.txt & del *.*" → Barcha fayllarni o'chiradi!
}

// ✅ Yaxshi - Validation
public string RunCommand(string filename)
{
    // Validate filename
    if (!Path.GetFileName(filename).Equals(filename))
    {
        throw new ArgumentException("Invalid filename");
    }
    
    if (!File.Exists(filename))
    {
        throw new FileNotFoundException();
    }
    
    return File.ReadAllText(filename);
}
```

**XSS (Cross-Site Scripting):**

```csharp
// ❌ Yomon - XSS vulnerability
public IActionResult DisplayComment(string comment)
{
    ViewBag.Comment = comment; // "<script>alert('XSS')</script>"
    return View();
}

// In View:
// @Html.Raw(ViewBag.Comment) // ❌ Script execute bo'ladi!

// ✅ Yaxshi - Encode output
public IActionResult DisplayComment(string comment)
{
    ViewBag.Comment = comment;
    return View();
}

// In View:
// @ViewBag.Comment // ✅ Auto-encoded

// Or manually:
// @Html.Encode(ViewBag.Comment)

// For rich text, use sanitizer
public class CommentService
{
    private readonly HtmlSanitizer _sanitizer;
    
    public string SanitizeComment(string html)
    {
        return _sanitizer.Sanitize(html);
    }
}
```

---

### 4. Insecure Design

**Muammo:** Secure bo'lmagan arxitektura

```csharp
// ❌ Yomon - Password reset without verification
public async Task<IActionResult> ResetPassword(string email, string newPassword)
{
    var user = await _userService.GetByEmailAsync(email);
    await _userService.UpdatePasswordAsync(user, newPassword);
    return Ok();
    // Har kim har qanday user'ning parolini o'zgartira oladi!
}

// ✅ Yaxshi - Token-based reset
public async Task<IActionResult> RequestPasswordReset(string email)
{
    var user = await _userService.GetByEmailAsync(email);
    if (user == null) return Ok(); // Don't reveal user existence
    
    var token = GenerateSecureToken();
    await _tokenService.SaveResetTokenAsync(user.Id, token, TimeSpan.FromHours(1));
    
    await _emailService.SendResetEmailAsync(email, token);
    return Ok();
}

public async Task<IActionResult> ResetPassword(string token, string newPassword)
{
    var userId = await _tokenService.ValidateTokenAsync(token);
    if (userId == null)
    {
        return BadRequest("Invalid or expired token");
    }
    
    await _userService.UpdatePasswordAsync(userId.Value, newPassword);
    await _tokenService.InvalidateTokenAsync(token);
    
    return Ok();
}

private string GenerateSecureToken()
{
    using var rng = RandomNumberGenerator.Create();
    var bytes = new byte[32];
    rng.GetBytes(bytes);
    return Convert.ToBase64String(bytes);
}
```

---

### 5. Security Misconfiguration

```csharp
// ❌ Yomon - Debug info production'da
public void Configure(IApplicationBuilder app)
{
    app.UseDeveloperExceptionPage(); // ❌ Stack trace ko'rinadi!
}

// ✅ Yaxshi - Environment-based configuration
public void Configure(IApplicationBuilder app, IWebHostEnvironment env)
{
    if (env.IsDevelopment())
    {
        app.UseDeveloperExceptionPage();
    }
    else
    {
        app.UseExceptionHandler("/Error");
        app.UseHsts();
    }
    
    app.UseHttpsRedirection();
    app.UseSecurityHeaders(); // Custom middleware
}

// Security Headers Middleware
public class SecurityHeadersMiddleware
{
    private readonly RequestDelegate _next;
    
    public async Task InvokeAsync(HttpContext context)
    {
        // X-Content-Type-Options
        context.Response.Headers.Add("X-Content-Type-Options", "nosniff");
        
        // X-Frame-Options
        context.Response.Headers.Add("X-Frame-Options", "DENY");
        
        // X-XSS-Protection
        context.Response.Headers.Add("X-XSS-Protection", "1; mode=block");
        
        // Strict-Transport-Security
        context.Response.Headers.Add(
            "Strict-Transport-Security", 
            "max-age=31536000; includeSubDomains"
        );
        
        // Content-Security-Policy
        context.Response.Headers.Add(
            "Content-Security-Policy",
            "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline';"
        );
        
        await _next(context);
    }
}
```

---

### 6. Vulnerable Components

```xml
<!-- ❌ Yomon - Outdated packages -->
<PackageReference Include="Newtonsoft.Json" Version="9.0.1" />
<!-- Known vulnerabilities! -->

<!-- ✅ Yaxshi - Latest stable versions -->
<PackageReference Include="Newtonsoft.Json" Version="13.0.3" />

<!-- Regular security scanning -->
```

```bash
# .NET vulnerability scanning
dotnet list package --vulnerable

# npm audit
npm audit
npm audit fix

# OWASP Dependency Check
dependency-check --project "MyProject" --scan .
```

---

### 7. Authentication Failures

```csharp
// JWT Authentication
public class AuthService
{
    private readonly IConfiguration _config;
    
    public string GenerateJwtToken(User user)
    {
        var securityKey = new SymmetricSecurityKey(
            Encoding.UTF8.GetBytes(_config["Jwt:SecretKey"])
        );
        var credentials = new SigningCredentials(
            securityKey, 
            SecurityAlgorithms.HmacSha256
        );
        
        var claims = new[]
        {
            new Claim(JwtRegisteredClaimNames.Sub, user.Id.ToString()),
            new Claim(JwtRegisteredClaimNames.Email, user.Email),
            new Claim(ClaimTypes.Role, user.Role),
            new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
        };
        
        var token = new JwtSecurityToken(
            issuer: _config["Jwt:Issuer"],
            audience: _config["Jwt:Audience"],
            claims: claims,
            expires: DateTime.UtcNow.AddHours(1), // Short expiry
            signingCredentials: credentials
        );
        
        return new JwtSecurityTokenHandler().WriteToken(token);
    }
}

// Refresh Token Pattern
public class TokenService
{
    public async Task<AuthResponse> RefreshTokenAsync(string refreshToken)
    {
        var token = await _tokenRepository.GetAsync(refreshToken);
        
        if (token == null || token.ExpiresAt < DateTime.UtcNow)
        {
            throw new SecurityException("Invalid refresh token");
        }
        
        var user = await _userRepository.GetAsync(token.UserId);
        
        var accessToken = GenerateJwtToken(user);
        var newRefreshToken = GenerateRefreshToken();
        
        await _tokenRepository.UpdateAsync(token.Id, newRefreshToken);
        
        return new AuthResponse
        {
            AccessToken = accessToken,
            RefreshToken = newRefreshToken
        };
    }
}

// Multi-Factor Authentication (MFA)
public class MfaService
{
    public async Task<string> GenerateMfaCodeAsync(int userId)
    {
        var code = new Random().Next(100000, 999999).ToString();
        
        await _cache.SetAsync(
            $"mfa:{userId}",
            code,
            TimeSpan.FromMinutes(5)
        );
        
        return code;
    }
    
    public async Task<bool> VerifyMfaCodeAsync(int userId, string code)
    {
        var cached = await _cache.GetAsync<string>($"mfa:{userId}");
        
        if (cached == code)
        {
            await _cache.RemoveAsync($"mfa:{userId}");
            return true;
        }
        
        return false;
    }
}
```

---

### 8. Software and Data Integrity Failures

```csharp
// Digital Signatures
public class SignatureService
{
    private readonly RSA _rsa;
    
    public byte[] SignData(byte[] data)
    {
        return _rsa.SignData(
            data,
            HashAlgorithmName.SHA256,
            RSASignaturePadding.Pkcs1
        );
    }
    
    public bool VerifySignature(byte[] data, byte[] signature)
    {
        return _rsa.VerifyData(
            data,
            signature,
            HashAlgorithmName.SHA256,
            RSASignaturePadding.Pkcs1
        );
    }
}

// File Upload Validation
public class FileUploadService
{
    private readonly string[] _allowedExtensions = { ".jpg", ".png", ".pdf" };
    private readonly long _maxFileSize = 10 * 1024 * 1024; // 10MB
    
    public async Task<UploadResult> UploadFileAsync(IFormFile file)
    {
        // Validate file extension
        var extension = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (!_allowedExtensions.Contains(extension))
        {
            throw new InvalidOperationException("File type not allowed");
        }
        
        // Validate file size
        if (file.Length > _maxFileSize)
        {
            throw new InvalidOperationException("File too large");
        }
        
        // Validate content type
        if (!IsValidContentType(file))
        {
            throw new InvalidOperationException("Invalid file content");
        }
        
        // Scan for malware (using ClamAV or similar)
        await ScanForMalwareAsync(file);
        
        // Generate secure filename
        var filename = $"{Guid.NewGuid()}{extension}";
        var path = Path.Combine(_uploadPath, filename);
        
        using var stream = new FileStream(path, FileMode.Create);
        await file.CopyToAsync(stream);
        
        return new UploadResult { Filename = filename, Path = path };
    }
    
    private bool IsValidContentType(IFormFile file)
    {
        // Check actual file content, not just extension
        using var reader = new BinaryReader(file.OpenReadStream());
        var headerBytes = reader.ReadBytes(8);
        
        // JPEG: FF D8 FF
        if (headerBytes[0] == 0xFF && 
            headerBytes[1] == 0xD8 && 
            headerBytes[2] == 0xFF)
        {
            return true;
        }
        
        // PNG: 89 50 4E 47
        if (headerBytes[0] == 0x89 && 
            headerBytes[1] == 0x50 && 
            headerBytes[2] == 0x4E && 
            headerBytes[3] == 0x47)
        {
            return true;
        }
        
        return false;
    }
}
```

---

### 9. Logging and Monitoring Failures

```csharp
// Secure Logging
public class SecureLogger
{
    private readonly ILogger _logger;
    
    public void LogUserAction(string action, User user)
    {
        _logger.LogInformation(
            "User {UserId} performed {Action} at {Timestamp}",
            user.Id, // ✅ Log user ID
            action,
            DateTime.UtcNow
        );
        
        // ❌ Don't log sensitive data
        // _logger.LogInformation($"Password: {user.Password}");
        // _logger.LogInformation($"Card: {user.CreditCard}");
    }
    
    public void LogAuthenticationFailure(string username, string ip)
    {
        _logger.LogWarning(
            "Failed login attempt for {Username} from {IP} at {Timestamp}",
            username,
            ip,
            DateTime.UtcNow
        );
        
        // Check for brute force
        await CheckBruteForceAttackAsync(ip);
    }
}

// Security Monitoring
public class SecurityMonitoringService
{
    public async Task CheckBruteForceAttackAsync(string ip)
    {
        var key = $"login:attempts:{ip}";
        var attempts = await _cache.GetAsync<int>(key);
        
        if (attempts >= 5)
        {
            // Block IP
            await _firewallService.BlockIpAsync(ip, TimeSpan.FromHours(1));
            
            // Send alert
            await _alertService.SendSecurityAlertAsync(
                $"Brute force attack detected from {ip}"
            );
        }
        else
        {
            await _cache.SetAsync(key, attempts + 1, TimeSpan.FromMinutes(15));
        }
    }
    
    public async Task DetectAnomalousActivityAsync(User user)
    {
        // Check unusual login location
        var currentIp = GetCurrentIp();
        var lastKnownIp = await _userRepository.GetLastIpAsync(user.Id);
        
        if (IsDifferentCountry(currentIp, lastKnownIp))
        {
            // Send verification email
            await _emailService.SendVerificationEmailAsync(user.Email);
        }
        
        // Check unusual transaction amount
        var avgTransaction = await GetAverageTransactionAsync(user.Id);
        var currentTransaction = GetCurrentTransaction();
        
        if (currentTransaction > avgTransaction * 10)
        {
            // Require additional verification
            await RequireMfaAsync(user.Id);
        }
    }
}
```

---

### 10. Server-Side Request Forgery (SSRF)

```csharp
// ❌ Yomon - SSRF vulnerability
public async Task<string> FetchUrlAsync(string url)
{
    using var client = new HttpClient();
    return await client.GetStringAsync(url);
    // Input: "http://localhost:8080/admin" → Internal service'ga kiradi!
}

// ✅ Yaxshi - URL validation
public async Task<string> FetchUrlAsync(string url)
{
    // Validate URL
    if (!Uri.TryCreate(url, UriKind.Absolute, out var uri))
    {
        throw new ArgumentException("Invalid URL");
    }
    
    // Block internal IPs
    var ip = await Dns.GetHostAddressesAsync(uri.Host);
    if (IsPrivateIp(ip[0]))
    {
        throw new SecurityException("Access to internal resources is forbidden");
    }
    
    // Whitelist domains
    var allowedDomains = new[] { "api.example.com", "cdn.example.com" };
    if (!allowedDomains.Contains(uri.Host))
    {
        throw new SecurityException("Domain not allowed");
    }
    
    using var client = new HttpClient();
    return await client.GetStringAsync(url);
}

private bool IsPrivateIp(IPAddress ip)
{
    var bytes = ip.GetAddressBytes();
    
    // 10.0.0.0/8
    if (bytes[0] == 10)
        return true;
    
    // 172.16.0.0/12
    if (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31)
        return true;
    
    // 192.168.0.0/16
    if (bytes[0] == 192 && bytes[1] == 168)
        return true;
    
    // 127.0.0.0/8 (localhost)
    if (bytes[0] == 127)
        return true;
    
    return false;
}
```

---

## Rate Limiting

```csharp
// Rate Limiting Middleware
public class RateLimitingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly IDistributedCache _cache;
    
    public async Task InvokeAsync(HttpContext context)
    {
        var ip = context.Connection.RemoteIpAddress?.ToString();
        var key = $"ratelimit:{ip}";
        
        var requests = await _cache.GetAsync<int>(key);
        
        if (requests >= 100) // 100 requests per minute
        {
            context.Response.StatusCode = 429; // Too Many Requests
            await context.Response.WriteAsync("Rate limit exceeded");
            return;
        }
        
        await _cache.SetAsync(key, requests + 1, TimeSpan.FromMinutes(1));
        await _next(context);
    }
}

// Using AspNetCoreRateLimit package
public class Startup
{
    public void ConfigureServices(IServiceCollection services)
    {
        services.AddMemoryCache();
        
        services.Configure<IpRateLimitOptions>(options =>
        {
            options.GeneralRules = new List<RateLimitRule>
            {
                new RateLimitRule
                {
                    Endpoint = "*",
                    Period = "1m",
                    Limit = 100
                },
                new RateLimitRule
                {
                    Endpoint = "*/api/auth/*",
                    Period = "1h",
                    Limit = 10
                }
            };
        });
        
        services.AddSingleton<IRateLimitConfiguration, RateLimitConfiguration>();
    }
}
```

---

## CORS (Cross-Origin Resource Sharing)

```csharp
public class Startup
{
    public void ConfigureServices(IServiceCollection services)
    {
        services.AddCors(options =>
        {
            // ❌ Yomon - Allow everything
            options.AddPolicy("AllowAll", builder =>
            {
                builder.AllowAnyOrigin()
                       .AllowAnyMethod()
                       .AllowAnyHeader();
            });
            
            // ✅ Yaxshi - Specific origins
            options.AddPolicy("Production", builder =>
            {
                builder.WithOrigins("https://example.com", "https://www.example.com")
                       .WithMethods("GET", "POST", "PUT", "DELETE")
                       .WithHeaders("Content-Type", "Authorization")
                       .AllowCredentials();
            });
        });
    }
    
    public void Configure(IApplicationBuilder app)
    {
        app.UseCors("Production");
    }
}
```

---

## API Security

```csharp
// API Key Authentication
public class ApiKeyAuthenticationHandler : AuthenticationHandler<ApiKeyAuthenticationOptions>
{
    private readonly IApiKeyService _apiKeyService;
    
    protected override async Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        if (!Request.Headers.TryGetValue("X-API-Key", out var apiKey))
        {
            return AuthenticateResult.Fail("API Key missing");
        }
        
        var client = await _apiKeyService.ValidateAsync(apiKey);
        if (client == null)
        {
            return AuthenticateResult.Fail("Invalid API Key");
        }
        
        var claims = new[]
        {
            new Claim(ClaimTypes.NameIdentifier, client.Id),
            new Claim(ClaimTypes.Name, client.Name)
        };
        
        var identity = new ClaimsIdentity(claims, Scheme.Name);
        var principal = new ClaimsPrincipal(identity);
        var ticket = new AuthenticationTicket(principal, Scheme.Name);
        
        return AuthenticateResult.Success(ticket);
    }
}

// Request Signing
public class RequestSignatureService
{
    public string SignRequest(string method, string path, string body, string secretKey)
    {
        var timestamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        var message = $"{method}:{path}:{body}:{timestamp}";
        
        using var hmac = new HMACSHA256(Encoding.UTF8.GetBytes(secretKey));
        var hash = hmac.ComputeHash(Encoding.UTF8.GetBytes(message));
        
        return Convert.ToBase64String(hash);
    }
    
    public bool VerifySignature(
        string signature,
        string method,
        string path,
        string body,
        string secretKey)
    {
        var expectedSignature = SignRequest(method, path, body, secretKey);
        return signature == expectedSignature;
    }
}
```

---

## Security Checklist

### Authentication:
- [ ] Strong password policy (min 8 chars, uppercase, lowercase, number, special)
- [ ] Password hashing (BCrypt, Argon2)
- [ ] Multi-factor authentication
- [ ] Account lockout after failed attempts
- [ ] Secure password reset flow

### Authorization:
- [ ] Role-based access control (RBAC)
- [ ] Policy-based authorization
- [ ] Least privilege principle
- [ ] Resource-level permissions

### Data Protection:
- [ ] Encryption at rest
- [ ] Encryption in transit (HTTPS/TLS)
- [ ] Sensitive data masking in logs
- [ ] Secure key management

### API Security:
- [ ] API authentication (JWT, API Key)
- [ ] Rate limiting
- [ ] CORS configuration
- [ ] Input validation
- [ ] Request signing

### Infrastructure:
- [ ] Security headers
- [ ] HTTPS enforcement
- [ ] Regular security updates
- [ ] Dependency scanning
- [ ] Firewall configuration

### Monitoring:
- [ ] Security event logging
- [ ] Failed login tracking
- [ ] Anomaly detection
- [ ] Security alerts
- [ ] Regular security audits

---

## Security Tools

### Scanning:
- **OWASP ZAP** - Vulnerability scanner
- **Burp Suite** - Web security testing
- **Nessus** - Network vulnerability scanner
- **SonarQube** - Code quality & security

### Monitoring:
- **Serilog** - Structured logging
- **Application Insights** - Monitoring
- **ELK Stack** - Log analysis

### Testing:
- **OWASP Dependency Check**
- **npm audit**
- **dotnet list package --vulnerable**

---

## Real-World Security Incident

### Case: Database Breach

**Attack:**
1. SQL Injection vulnerability
2. Attacker extracted user data
3. 10 million records leaked

**Damage:**
- $50 million fine
- Brand reputation damaged
- Users lost trust

**Prevention:**
```csharp
// ✅ Use parameterized queries
// ✅ Input validation
// ✅ Least privilege DB user
// ✅ Encryption at rest
// ✅ Security monitoring
```

---

## Keyingi Qadamlar

Security asoslarini o'rgandingiz! Endi:

1. **DevOps & CI/CD** - Automation
2. **Cloud Security** - AWS/Azure security
3. **Penetration Testing** - Hacking skills

**Mashq:** O'z loyihangizda security audit o'tkazing va zaifliklarni toping!

Keyingi: [DevOps & CI/CD](./09-devops.md)
