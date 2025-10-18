# SOLID Prinsiplari - To'liq Qo'llanma

SOLID - bu 5 ta asosiy OOP (Object-Oriented Programming) prinsiplari bo'lib, kodni tushunarli, moslashuvchan va kengaytiriladigan qiladi.

---

## SOLID nima?

```
S - Single Responsibility Principle (SRP)
O - Open/Closed Principle (OCP)
L - Liskov Substitution Principle (LSP)
I - Interface Segregation Principle (ISP)
D - Dependency Inversion Principle (DIP)
```

---

## 1. Single Responsibility Principle (SRP)

### Qoida
**"Har bir class faqat BITTA sabab bo'yicha o'zgarishi kerak"**

Yoki boshqacha aytganda:
**"Har bir class faqat BITTA vazifani bajarishi kerak"**

### Nima uchun muhim?
- Kodni tushunish oson
- O'zgartirish xavfsiz
- Qayta ishlatish oson
- Test qilish oson

---

### ❌ Noto'g'ri Misol

```csharp
// Bu class juda ko'p narsani qilmoqda!
public class User
{
    public string Name { get; set; }
    public string Email { get; set; }
    public string Password { get; set; }
    
    // 1. Vazifa: Validation
    public bool Validate()
    {
        if (string.IsNullOrEmpty(Name))
            return false;
        if (!Email.Contains("@"))
            return false;
        if (Password.Length < 8)
            return false;
        return true;
    }
    
    // 2. Vazifa: Database operations
    public void Save()
    {
        using (var connection = new SqlConnection("..."))
        {
            var command = new SqlCommand(
                "INSERT INTO Users (Name, Email, Password) VALUES (@name, @email, @password)", 
                connection);
            command.Parameters.AddWithValue("@name", Name);
            command.Parameters.AddWithValue("@email", Email);
            command.Parameters.AddWithValue("@password", Password);
            connection.Open();
            command.ExecuteNonQuery();
        }
    }
    
    // 3. Vazifa: Email sending
    public void SendWelcomeEmail()
    {
        var smtpClient = new SmtpClient("smtp.gmail.com")
        {
            Credentials = new NetworkCredential("user@gmail.com", "password"),
            EnableSsl = true
        };
        
        var mailMessage = new MailMessage
        {
            From = new MailAddress("noreply@example.com"),
            Subject = "Welcome!",
            Body = $"Hello {Name}, welcome to our platform!",
            IsBodyHtml = true,
        };
        mailMessage.To.Add(Email);
        
        smtpClient.Send(mailMessage);
    }
    
    // 4. Vazifa: Logging
    public void LogActivity(string activity)
    {
        File.AppendAllText("user_log.txt", 
            $"{DateTime.Now}: User {Name} - {activity}\n");
    }
}
```

**Muammo:**
- User class 4 ta vazifani bajarmoqda!
- Email yuborish logikasi o'zgarsa, User class'ni o'zgartirish kerak
- Database o'zgarsa, User class'ni o'zgartirish kerak
- Logging mexanizmi o'zgarsa, User class'ni o'zgartirish kerak
- Test qilish qiyin

---

### ✅ To'g'ri Misol

```csharp
// 1. User Entity - faqat user ma'lumotlari
public class User
{
    public int Id { get; set; }
    public string Name { get; set; }
    public string Email { get; set; }
    public string Password { get; set; }
    
    public User(string name, string email, string password)
    {
        Name = name;
        Email = email;
        Password = password;
    }
}

// 2. Validator - faqat validation
public class UserValidator
{
    public ValidationResult Validate(User user)
    {
        var errors = new List<string>();
        
        if (string.IsNullOrEmpty(user.Name))
            errors.Add("Name is required");
            
        if (!IsValidEmail(user.Email))
            errors.Add("Email is invalid");
            
        if (user.Password.Length < 8)
            errors.Add("Password must be at least 8 characters");
            
        return new ValidationResult(errors.Any() == false, errors);
    }
    
    private bool IsValidEmail(string email)
    {
        return !string.IsNullOrEmpty(email) && email.Contains("@");
    }
}

// 3. Repository - faqat database operations
public class UserRepository
{
    private readonly string _connectionString;
    
    public UserRepository(string connectionString)
    {
        _connectionString = connectionString;
    }
    
    public void Save(User user)
    {
        using (var connection = new SqlConnection(_connectionString))
        {
            var command = new SqlCommand(
                "INSERT INTO Users (Name, Email, Password) VALUES (@name, @email, @password)", 
                connection);
            command.Parameters.AddWithValue("@name", user.Name);
            command.Parameters.AddWithValue("@email", user.Email);
            command.Parameters.AddWithValue("@password", user.Password);
            connection.Open();
            command.ExecuteNonQuery();
        }
    }
    
    public User GetById(int id)
    {
        // ... kod
        return null;
    }
}

// 4. Email Service - faqat email sending
public class EmailService
{
    private readonly SmtpClient _smtpClient;
    
    public EmailService(SmtpClient smtpClient)
    {
        _smtpClient = smtpClient;
    }
    
    public void SendWelcomeEmail(User user)
    {
        var mailMessage = new MailMessage
        {
            From = new MailAddress("noreply@example.com"),
            Subject = "Welcome!",
            Body = $"Hello {user.Name}, welcome to our platform!",
            IsBodyHtml = true,
        };
        mailMessage.To.Add(user.Email);
        
        _smtpClient.Send(mailMessage);
    }
}

// 5. Logger - faqat logging
public class UserActivityLogger
{
    private readonly string _logFilePath;
    
    public UserActivityLogger(string logFilePath)
    {
        _logFilePath = logFilePath;
    }
    
    public void LogActivity(User user, string activity)
    {
        File.AppendAllText(_logFilePath, 
            $"{DateTime.Now}: User {user.Name} - {activity}\n");
    }
}

// Ishlatish
public class UserRegistrationService
{
    private readonly UserValidator _validator;
    private readonly UserRepository _repository;
    private readonly EmailService _emailService;
    private readonly UserActivityLogger _logger;
    
    public UserRegistrationService(
        UserValidator validator,
        UserRepository repository,
        EmailService emailService,
        UserActivityLogger logger)
    {
        _validator = validator;
        _repository = repository;
        _emailService = emailService;
        _logger = logger;
    }
    
    public void RegisterUser(string name, string email, string password)
    {
        // 1. User yaratish
        var user = new User(name, email, password);
        
        // 2. Validation
        var validationResult = _validator.Validate(user);
        if (!validationResult.IsValid)
        {
            throw new ValidationException(validationResult.Errors);
        }
        
        // 3. Saqlash
        _repository.Save(user);
        
        // 4. Email yuborish
        _emailService.SendWelcomeEmail(user);
        
        // 5. Log qilish
        _logger.LogActivity(user, "User registered");
    }
}
```

**Natija:**
- ✅ Har bir class bitta vazifani bajaradi
- ✅ O'zgartirish oson va xavfsiz
- ✅ Test qilish oson
- ✅ Kod qayta ishlatiladi

---

## 2. Open/Closed Principle (OCP)

### Qoida
**"Class'lar kengaytirish uchun ochiq, o'zgartirish uchun yopiq bo'lishi kerak"**

Ya'ni:
- ✅ Yangi funksionallik qo'shish mumkin (extend)
- ❌ Mavjud kodni o'zgartirmaslik kerak (modify)

### Nima uchun muhim?
- Mavjud kodni buzmasdan yangi funksionallik qo'shish
- Regression bug'lar ehtimoli kamayadi
- Yaxshi test qilingan kod o'zgarmasligi

---

### ❌ Noto'g'ri Misol

```csharp
public class OrderProcessor
{
    public decimal CalculateDiscount(Order order, string customerType)
    {
        decimal discount = 0;
        
        if (customerType == "Regular")
        {
            discount = order.TotalAmount * 0.05m; // 5%
        }
        else if (customerType == "Premium")
        {
            discount = order.TotalAmount * 0.10m; // 10%
        }
        else if (customerType == "VIP")
        {
            discount = order.TotalAmount * 0.20m; // 20%
        }
        // Yangi customer type qo'shish uchun bu kodni o'zgartirish kerak! ❌
        
        return discount;
    }
}
```

**Muammo:**
- Yangi customer type qo'shish uchun `OrderProcessor` class'ni o'zgartirish kerak
- Har safar o'zgartirganda test qilish kerak
- Bug kirishi ehtimoli yuqori

---

### ✅ To'g'ri Misol

```csharp
// 1. Interface yaratish
public interface IDiscountStrategy
{
    decimal CalculateDiscount(Order order);
}

// 2. Har bir customer type uchun alohida class
public class RegularCustomerDiscount : IDiscountStrategy
{
    public decimal CalculateDiscount(Order order)
    {
        return order.TotalAmount * 0.05m; // 5%
    }
}

public class PremiumCustomerDiscount : IDiscountStrategy
{
    public decimal CalculateDiscount(Order order)
    {
        return order.TotalAmount * 0.10m; // 10%
    }
}

public class VIPCustomerDiscount : IDiscountStrategy
{
    public decimal CalculateDiscount(Order order)
    {
        return order.TotalAmount * 0.20m; // 20%
    }
}

// 3. Yangi customer type - YANGI CLASS, eski kod o'zgarmaydi!
public class GoldCustomerDiscount : IDiscountStrategy
{
    public decimal CalculateDiscount(Order order)
    {
        return order.TotalAmount * 0.25m; // 25%
    }
}

// 4. OrderProcessor - hech qachon o'zgarmaydigan class
public class OrderProcessor
{
    private readonly IDiscountStrategy _discountStrategy;
    
    public OrderProcessor(IDiscountStrategy discountStrategy)
    {
        _discountStrategy = discountStrategy;
    }
    
    public decimal CalculateDiscount(Order order)
    {
        return _discountStrategy.CalculateDiscount(order);
    }
}

// Ishlatish
var regularProcessor = new OrderProcessor(new RegularCustomerDiscount());
var discount1 = regularProcessor.CalculateDiscount(order);

var vipProcessor = new OrderProcessor(new VIPCustomerDiscount());
var discount2 = vipProcessor.CalculateDiscount(order);

// Yangi Gold customer - faqat yangi class qo'shish!
var goldProcessor = new OrderProcessor(new GoldCustomerDiscount());
var discount3 = goldProcessor.CalculateDiscount(order);
```

**Natija:**
- ✅ Yangi discount type qo'shish uchun faqat yangi class yaratish kerak
- ✅ Eski kod o'zgarmaydi
- ✅ Eski testlar ishlab turadi
- ✅ Xavfsiz

---

### Yana bir misol: Report Generator

```csharp
// ❌ NOTO'G'RI
public class ReportGenerator
{
    public void Generate(Report report, string format)
    {
        if (format == "PDF")
        {
            // PDF generatsiya
        }
        else if (format == "Excel")
        {
            // Excel generatsiya
        }
        else if (format == "Word")
        {
            // Word generatsiya
        }
        // Yangi format uchun kod o'zgartirish kerak! ❌
    }
}

// ✅ TO'G'RI
public interface IReportFormatter
{
    void Generate(Report report);
}

public class PdfReportFormatter : IReportFormatter
{
    public void Generate(Report report)
    {
        // PDF generatsiya
    }
}

public class ExcelReportFormatter : IReportFormatter
{
    public void Generate(Report report)
    {
        // Excel generatsiya
    }
}

// Yangi format - faqat yangi class!
public class JsonReportFormatter : IReportFormatter
{
    public void Generate(Report report)
    {
        // JSON generatsiya
    }
}

public class ReportGenerator
{
    private readonly IReportFormatter _formatter;
    
    public ReportGenerator(IReportFormatter formatter)
    {
        _formatter = formatter;
    }
    
    public void Generate(Report report)
    {
        _formatter.Generate(report);
    }
}
```

---

## 3. Liskov Substitution Principle (LSP)

### Qoida
**"Base class o'rniga derived class ishlatilganda, dastur to'g'ri ishlashi kerak"**

Ya'ni:
- Child class parent class'ning xatti-harakatlarini buzmasligi kerak
- Polimorfizm to'g'ri ishlashi uchun

---

### ❌ Noto'g'ri Misol

```csharp
// Base class
public class Bird
{
    public virtual void Fly()
    {
        Console.WriteLine("Bird is flying");
    }
}

// Derived class 1 - OK
public class Eagle : Bird
{
    public override void Fly()
    {
        Console.WriteLine("Eagle is flying high");
    }
}

// Derived class 2 - MUAMMO! ❌
public class Penguin : Bird
{
    public override void Fly()
    {
        // Penguin ucha olmaydi!
        throw new NotImplementedException("Penguins cannot fly!");
    }
}

// Ishlatish
void MakeBirdFly(Bird bird)
{
    bird.Fly(); // Penguin uchun xato!
}

var eagle = new Eagle();
MakeBirdFly(eagle); // ✅ OK

var penguin = new Penguin();
MakeBirdFly(penguin); // ❌ Exception!
```

**Muammo:**
- `Penguin` class `Bird` class'ning xatti-harakatini buzadi
- `Bird` o'rniga `Penguin` ishlatib bo'lmaydi
- LSP buzilgan!

---

### ✅ To'g'ri Misol

```csharp
// Abstraction'ni qayta ko'rib chiqish kerak
public abstract class Bird
{
    public abstract void Move();
}

// Uchuvchi qushlar
public class FlyingBird : Bird
{
    public virtual void Fly()
    {
        Console.WriteLine("Bird is flying");
    }
    
    public override void Move()
    {
        Fly();
    }
}

// Uchmaydigan qushlar
public class FlightlessBird : Bird
{
    public virtual void Walk()
    {
        Console.WriteLine("Bird is walking");
    }
    
    public override void Move()
    {
        Walk();
    }
}

// Endi to'g'ri
public class Eagle : FlyingBird
{
    public override void Fly()
    {
        Console.WriteLine("Eagle is flying high");
    }
}

public class Penguin : FlightlessBird
{
    public override void Walk()
    {
        Console.WriteLine("Penguin is waddling");
    }
}

// Ishlatish
void MakeBirdMove(Bird bird)
{
    bird.Move(); // Barcha qushlar uchun ishlaydi!
}

var eagle = new Eagle();
MakeBirdMove(eagle); // ✅ Flying

var penguin = new Penguin();
MakeBirdMove(penguin); // ✅ Walking
```

---

### Yana bir misol: Rectangle va Square

```csharp
// ❌ NOTO'G'RI - Klassik LSP buzilish misoli
public class Rectangle
{
    public virtual int Width { get; set; }
    public virtual int Height { get; set; }
    
    public int CalculateArea()
    {
        return Width * Height;
    }
}

public class Square : Rectangle
{
    public override int Width
    {
        get => base.Width;
        set
        {
            base.Width = value;
            base.Height = value; // Width o'zgarganda Height ham o'zgaradi
        }
    }
    
    public override int Height
    {
        get => base.Height;
        set
        {
            base.Width = value;
            base.Height = value; // Height o'zgarganda Width ham o'zgaradi
        }
    }
}

// Test
void TestRectangle(Rectangle rect)
{
    rect.Width = 5;
    rect.Height = 10;
    
    // Kutilgan natija: 50
    // Square uchun: 100 (muammo!)
    Assert.AreEqual(50, rect.CalculateArea());
}

var rectangle = new Rectangle();
TestRectangle(rectangle); // ✅ Pass

var square = new Square();
TestRectangle(square); // ❌ Fail!

// ✅ TO'G'RI
public interface IShape
{
    int CalculateArea();
}

public class Rectangle : IShape
{
    public int Width { get; set; }
    public int Height { get; set; }
    
    public int CalculateArea()
    {
        return Width * Height;
    }
}

public class Square : IShape
{
    public int Side { get; set; }
    
    public int CalculateArea()
    {
        return Side * Side;
    }
}
```

---

## 4. Interface Segregation Principle (ISP)

### Qoida
**"Client'lar ishlatmaydigan method'larga bog'liq bo'lmasligi kerak"**

Ya'ni:
- Katta interface'larni kichikroq interface'larga bo'lish
- Har bir client faqat kerakli method'larga ega interface ishlatadi

---

### ❌ Noto'g'ri Misol

```csharp
// Juda katta interface - "Fat Interface"
public interface IWorker
{
    void Work();
    void Eat();
    void Sleep();
    void GetPaid();
}

// Odam - barcha method'lar kerak
public class HumanWorker : IWorker
{
    public void Work()
    {
        Console.WriteLine("Human working");
    }
    
    public void Eat()
    {
        Console.WriteLine("Human eating");
    }
    
    public void Sleep()
    {
        Console.WriteLine("Human sleeping");
    }
    
    public void GetPaid()
    {
        Console.WriteLine("Human getting paid");
    }
}

// Robot - ba'zi method'lar kerak emas! ❌
public class RobotWorker : IWorker
{
    public void Work()
    {
        Console.WriteLine("Robot working");
    }
    
    public void Eat()
    {
        // Robot ovqatlanmaydi!
        throw new NotImplementedException();
    }
    
    public void Sleep()
    {
        // Robot uxlamaydi!
        throw new NotImplementedException();
    }
    
    public void GetPaid()
    {
        // Robot maosh olmaydi!
        throw new NotImplementedException();
    }
}
```

**Muammo:**
- `RobotWorker` ishlatmaydigan method'larni implement qilishga majbur
- ISP buzilgan!

---

### ✅ To'g'ri Misol

```csharp
// Kichik, aniq interface'lar
public interface IWorkable
{
    void Work();
}

public interface IFeedable
{
    void Eat();
}

public interface ISleepable
{
    void Sleep();
}

public interface IPayable
{
    void GetPaid();
}

// Odam - barcha interface'larni implement qiladi
public class HumanWorker : IWorkable, IFeedable, ISleepable, IPayable
{
    public void Work()
    {
        Console.WriteLine("Human working");
    }
    
    public void Eat()
    {
        Console.WriteLine("Human eating");
    }
    
    public void Sleep()
    {
        Console.WriteLine("Human sleeping");
    }
    
    public void GetPaid()
    {
        Console.WriteLine("Human getting paid");
    }
}

// Robot - faqat kerakli interface
public class RobotWorker : IWorkable
{
    public void Work()
    {
        Console.WriteLine("Robot working");
    }
}

// Manager - faqat WorkManager uchun kerakli interface
public class WorkManager
{
    public void ManageWork(IWorkable worker)
    {
        worker.Work(); // Faqat Work() method kerak
    }
}

// Ishlatish
var manager = new WorkManager();

var human = new HumanWorker();
manager.ManageWork(human); // ✅

var robot = new RobotWorker();
manager.ManageWork(robot); // ✅
```

---

### Yana bir misol: Printer

```csharp
// ❌ NOTO'G'RI
public interface IPrinter
{
    void Print(Document doc);
    void Scan(Document doc);
    void Fax(Document doc);
    void Copy(Document doc);
}

// Oddiy printer - faqat print qiladi
public class SimplePrinter : IPrinter
{
    public void Print(Document doc)
    {
        Console.WriteLine("Printing...");
    }
    
    // Kerak emas! ❌
    public void Scan(Document doc)
    {
        throw new NotImplementedException();
    }
    
    public void Fax(Document doc)
    {
        throw new NotImplementedException();
    }
    
    public void Copy(Document doc)
    {
        throw new NotImplementedException();
    }
}

// ✅ TO'G'RI
public interface IPrinter
{
    void Print(Document doc);
}

public interface IScanner
{
    void Scan(Document doc);
}

public interface IFax
{
    void Fax(Document doc);
}

public interface ICopier
{
    void Copy(Document doc);
}

// Oddiy printer
public class SimplePrinter : IPrinter
{
    public void Print(Document doc)
    {
        Console.WriteLine("Printing...");
    }
}

// Multifunctional printer
public class MultiFunctionPrinter : IPrinter, IScanner, IFax, ICopier
{
    public void Print(Document doc)
    {
        Console.WriteLine("Printing...");
    }
    
    public void Scan(Document doc)
    {
        Console.WriteLine("Scanning...");
    }
    
    public void Fax(Document doc)
    {
        Console.WriteLine("Faxing...");
    }
    
    public void Copy(Document doc)
    {
        Console.WriteLine("Copying...");
    }
}
```

---

## 5. Dependency Inversion Principle (DIP)

### Qoida
**"High-level module'lar low-level module'larga bog'liq bo'lmasligi kerak. Ikkalasi ham abstraction'larga bog'liq bo'lishi kerak"**

Ya'ni:
- Concrete class'larga emas, interface/abstract class'larga bog'lanish
- Dependency Injection ishlatish

---

### ❌ Noto'g'ri Misol

```csharp
// Low-level module
public class EmailService
{
    public void SendEmail(string to, string subject, string body)
    {
        Console.WriteLine($"Sending email to {to}");
        // SMTP logic
    }
}

// High-level module - concrete class'ga bog'liq! ❌
public class UserService
{
    private EmailService _emailService = new EmailService(); // ❌
    
    public void RegisterUser(string name, string email)
    {
        // User registration logic
        
        // Email yuborish
        _emailService.SendEmail(email, "Welcome", $"Hello {name}");
    }
}
```

**Muammo:**
- `UserService` `EmailService`'ga qattiq bog'langan
- Email service'ni o'zgartirish qiyin
- SMS yoki Push notification qo'shish qiyin
- Test qilish qiyin

---

### ✅ To'g'ri Misol

```csharp
// 1. Abstraction yaratish
public interface INotificationService
{
    void Send(string to, string subject, string message);
}

// 2. Low-level module'lar - Interface'ni implement qiladi
public class EmailService : INotificationService
{
    public void Send(string to, string subject, string message)
    {
        Console.WriteLine($"Sending email to {to}");
        // SMTP logic
    }
}

public class SmsService : INotificationService
{
    public void Send(string to, string subject, string message)
    {
        Console.WriteLine($"Sending SMS to {to}");
        // SMS API logic
    }
}

public class PushNotificationService : INotificationService
{
    public void Send(string to, string subject, string message)
    {
        Console.WriteLine($"Sending push notification to {to}");
        // Push notification logic
    }
}

// 3. High-level module - Interface'ga bog'liq ✅
public class UserService
{
    private readonly INotificationService _notificationService;
    
    // Dependency Injection
    public UserService(INotificationService notificationService)
    {
        _notificationService = notificationService;
    }
    
    public void RegisterUser(string name, string contact)
    {
        // User registration logic
        
        // Notification yuborish
        _notificationService.Send(contact, "Welcome", $"Hello {name}");
    }
}

// Ishlatish
// Email bilan
var userServiceWithEmail = new UserService(new EmailService());
userServiceWithEmail.RegisterUser("Ali", "ali@example.com");

// SMS bilan
var userServiceWithSms = new UserService(new SmsService());
userServiceWithSms.RegisterUser("Vali", "+998901234567");

// Push notification bilan
var userServiceWithPush = new UserService(new PushNotificationService());
userServiceWithPush.RegisterUser("Sardor", "user_device_token");
```

**Natija:**
- ✅ `UserService` interface'ga bog'liq, concrete class'ga emas
- ✅ Notification service'ni osongina almashtirish mumkin
- ✅ Test qilish oson (mock ishlatish)
- ✅ Yangi notification type qo'shish oson

---

### Dependency Injection Container bilan

```csharp
// ASP.NET Core da
public class Startup
{
    public void ConfigureServices(IServiceCollection services)
    {
        // Dependency Injection
        services.AddScoped<INotificationService, EmailService>();
        services.AddScoped<UserService>();
    }
}

// Controller'da
public class UserController : ControllerBase
{
    private readonly UserService _userService;
    
    // Constructor injection
    public UserController(UserService userService)
    {
        _userService = userService;
    }
    
    [HttpPost("register")]
    public IActionResult Register(RegisterDto dto)
    {
        _userService.RegisterUser(dto.Name, dto.Email);
        return Ok();
    }
}
```

---

## SOLID Prinsiplarini Birgalikda Qo'llash

### Amaliy Misol: Order Processing System

```csharp
// ===============================================
// 1. ENTITIES (Single Responsibility)
// ===============================================
public class Order
{
    public Guid Id { get; private set; }
    public decimal TotalAmount { get; private set; }
    public OrderStatus Status { get; private set; }
    
    public void Confirm()
    {
        if (Status != OrderStatus.Pending)
            throw new InvalidOperationException("Only pending orders can be confirmed");
            
        Status = OrderStatus.Confirmed;
    }
}

// ===============================================
// 2. ABSTRACTIONS (Dependency Inversion)
// ===============================================
public interface IOrderRepository
{
    Task SaveAsync(Order order);
    Task<Order> GetByIdAsync(Guid id);
}

public interface IPaymentGateway
{
    Task<PaymentResult> ProcessPaymentAsync(decimal amount);
}

public interface INotificationService
{
    Task SendAsync(string recipient, string message);
}

// Interface Segregation - kichik interface'lar
public interface IOrderValidator
{
    ValidationResult Validate(Order order);
}

public interface IDiscountCalculator
{
    decimal Calculate(Order order);
}

// ===============================================
// 3. IMPLEMENTATIONS (Open/Closed)
// ===============================================

// Discount strategiyalari - Open/Closed
public class NoDiscount : IDiscountCalculator
{
    public decimal Calculate(Order order) => 0;
}

public class PercentageDiscount : IDiscountCalculator
{
    private readonly decimal _percentage;
    
    public PercentageDiscount(decimal percentage)
    {
        _percentage = percentage;
    }
    
    public decimal Calculate(Order order)
    {
        return order.TotalAmount * _percentage;
    }
}

// Payment gateway implementations
public class StripePaymentGateway : IPaymentGateway
{
    public async Task<PaymentResult> ProcessPaymentAsync(decimal amount)
    {
        // Stripe API
        return new PaymentResult { Success = true };
    }
}

public class PayPalPaymentGateway : IPaymentGateway
{
    public async Task<PaymentResult> ProcessPaymentAsync(decimal amount)
    {
        // PayPal API
        return new PaymentResult { Success = true };
    }
}

// ===============================================
// 4. USE CASE (Single Responsibility + DIP)
// ===============================================
public class ProcessOrderUseCase
{
    private readonly IOrderRepository _orderRepository;
    private readonly IPaymentGateway _paymentGateway;
    private readonly INotificationService _notificationService;
    private readonly IOrderValidator _validator;
    private readonly IDiscountCalculator _discountCalculator;
    
    // Dependency Injection
    public ProcessOrderUseCase(
        IOrderRepository orderRepository,
        IPaymentGateway paymentGateway,
        INotificationService notificationService,
        IOrderValidator validator,
        IDiscountCalculator discountCalculator)
    {
        _orderRepository = orderRepository;
        _paymentGateway = paymentGateway;
        _notificationService = notificationService;
        _validator = validator;
        _discountCalculator = discountCalculator;
    }
    
    public async Task<ProcessOrderResult> ExecuteAsync(Guid orderId)
    {
        // 1. Buyurtmani olish
        var order = await _orderRepository.GetByIdAsync(orderId);
        if (order == null)
            throw new NotFoundException("Order not found");
        
        // 2. Validation
        var validationResult = _validator.Validate(order);
        if (!validationResult.IsValid)
            throw new ValidationException(validationResult.Errors);
        
        // 3. Discount hisoblash
        var discount = _discountCalculator.Calculate(order);
        var finalAmount = order.TotalAmount - discount;
        
        // 4. To'lov
        var paymentResult = await _paymentGateway.ProcessPaymentAsync(finalAmount);
        if (!paymentResult.Success)
            throw new PaymentException("Payment failed");
        
        // 5. Order ni tasdiqlash
        order.Confirm();
        await _orderRepository.SaveAsync(order);
        
        // 6. Notification
        await _notificationService.SendAsync(
            "customer@example.com", 
            "Your order has been confirmed!"
        );
        
        return new ProcessOrderResult
        {
            Success = true,
            OrderId = order.Id,
            FinalAmount = finalAmount
        };
    }
}

// ===============================================
// 5. CONFIGURATION (Dependency Injection)
// ===============================================
public class Startup
{
    public void ConfigureServices(IServiceCollection services)
    {
        // Repositories
        services.AddScoped<IOrderRepository, OrderRepository>();
        
        // Payment - osongina almashtirish mumkin!
        services.AddScoped<IPaymentGateway, StripePaymentGateway>();
        // yoki
        // services.AddScoped<IPaymentGateway, PayPalPaymentGateway>();
        
        // Notifications
        services.AddScoped<INotificationService, EmailService>();
        
        // Validators
        services.AddScoped<IOrderValidator, OrderValidator>();
        
        // Discount - konfiguratsiyaga qarab
        services.AddScoped<IDiscountCalculator>(provider => 
            new PercentageDiscount(0.10m)); // 10% discount
        
        // Use Cases
        services.AddScoped<ProcessOrderUseCase>();
    }
}
```

**Bu kodda SOLID prinsiplari:**
- ✅ **SRP**: Har bir class bitta vazifani bajaradi
- ✅ **OCP**: Yangi discount yoki payment type qo'shish uchun yangi class yaratish kifoya
- ✅ **LSP**: Barcha implementation'lar to'g'ri ishlaydi
- ✅ **ISP**: Kichik, aniq interface'lar
- ✅ **DIP**: Interface'larga bog'lanish, dependency injection

---

## SOLID ni Buzish Belgilari

### 🚨 SRP buzilgan:
- Class nomi "Manager", "Helper", "Utility" bilan tugaydi
- Class'da 10+ method bor
- "va" so'zi bilan tavsiflanadi: "User validator VA saver"

### 🚨 OCP buzilgan:
- Yangi funksionallik uchun if/switch qo'shish kerak
- Bir joyni o'zgartirganda ko'p joylar buziladi

### 🚨 LSP buzilgan:
- Derived class'da `NotImplementedException`
- Base class o'rniga child class ishlatilmaydi
- Type checking: `if (obj is SpecificType)`

### 🚨 ISP buzilgan:
- Interface'da 10+ method
- Empty implementation'lar
- Method'lar turli vazifalarni bajaradi

### 🚨 DIP buzilgan:
- `new` keyword class ichida
- Concrete class'larga dependency
- Static method'lardan foydalanish

---

## Amaliy Mashqlar

### Mashq 1: SRP
Quyidagi class'ni bir nechta class'larga bo'ling:

```csharp
public class Invoice
{
    public void CalculateTotal() { }
    public void SaveToDatabase() { }
    public void SendEmail() { }
    public void PrintPdf() { }
    public void ValidateData() { }
}
```

### Mashq 2: OCP
Payment processor'ni Open/Closed prinsipiga muvofiq yozing:
- Credit Card
- PayPal  
- Bitcoin

### Mashq 3: DIP
Dependency Injection ishlatib User registration tizimi yozing:
- Email verification
- SMS verification
- Database save

---

## Keyingi Qadamlar

SOLID prinsiplarini o'rgandingiz! Endi:

1. **Design Patterns** - SOLID asosidagi umumiy yechimlar
2. **Clean Architecture** - SOLID prinsiplarini arxitekturada qo'llash
3. **Refactoring** - Mavjud kodni SOLID ga moslash

Keyingi bo'lim: [Design Patterns](./03-design-patterns.md)
