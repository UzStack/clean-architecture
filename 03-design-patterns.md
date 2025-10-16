# Design Patterns - To'liq Qo'llanma

Design Patterns - bu dasturlashda tez-tez uchraydigan muammolarga tayyor yechimlar.

---

## Design Patterns Turlari

```
1. Creational Patterns (Yaratish) - Obyektlarni qanday yaratish
2. Structural Patterns (Strukturaviy) - Obyektlar va class'larni qanday tashkil qilish
3. Behavioral Patterns (Xatti-harakat) - Obyektlar o'rtasida qanday muloqot qilish
```

---

## CREATIONAL PATTERNS

### 1. Singleton Pattern

**Maqsad:** Class'dan faqat BITTA instance yaratish

**Qachon kerak?**
- Configuration manager
- Logger
- Database connection pool
- Cache manager

#### ❌ Muammo

```csharp
// Har safar yangi instance!
var config1 = new Configuration();
var config2 = new Configuration();
// config1 != config2
```

#### ✅ Yechim

```csharp
public class Configuration
{
    private static Configuration _instance;
    private static readonly object _lock = new object();
    
    // Private constructor - tashqaridan yangi instance yaratib bo'lmaydi
    private Configuration()
    {
        // Configuration yuklash
    }
    
    // Yagona kirish nuqtasi
    public static Configuration Instance
    {
        get
        {
            if (_instance == null)
            {
                lock (_lock) // Thread-safe
                {
                    if (_instance == null)
                    {
                        _instance = new Configuration();
                    }
                }
            }
            return _instance;
        }
    }
    
    public string GetSetting(string key)
    {
        // Settings'dan qiymat olish
        return "value";
    }
}

// Ishlatish
var config = Configuration.Instance;
var dbConnection = config.GetSetting("DatabaseConnection");

// Har doim bir xil instance
var config2 = Configuration.Instance;
// config == config2 ✅
```

#### Modern C# da (Thread-safe, lazy)

```csharp
public sealed class Configuration
{
    private static readonly Lazy<Configuration> _lazy = 
        new Lazy<Configuration>(() => new Configuration());
    
    public static Configuration Instance => _lazy.Value;
    
    private Configuration()
    {
    }
}
```

**Diqqat:** Singleton'dan ko'p foydalanish yomon! Global state yaratadi va testing qiyinlashtiradi.

---

### 2. Factory Pattern

**Maqsad:** Obyekt yaratish logikasini yashirish

**Qachon kerak?**
- Obyekt yaratish murakkab
- Qaysi class yaratish kerakligini runtime'da bilish kerak

#### ❌ Muammo

```csharp
// Client murakkab yaratish logikasini bilishi kerak
public void ProcessPayment(string type, decimal amount)
{
    IPaymentProcessor processor;
    
    if (type == "creditcard")
    {
        processor = new CreditCardProcessor(
            new CreditCardValidator(),
            new EncryptionService(),
            new FraudDetector()
        );
    }
    else if (type == "paypal")
    {
        processor = new PayPalProcessor(
            new PayPalApiClient(),
            new TokenManager()
        );
    }
    // ... murakkab kod
}
```

#### ✅ Yechim

```csharp
// 1. Product interface
public interface IPaymentProcessor
{
    PaymentResult Process(decimal amount);
}

// 2. Concrete products
public class CreditCardProcessor : IPaymentProcessor
{
    public PaymentResult Process(decimal amount)
    {
        Console.WriteLine("Processing credit card payment");
        return new PaymentResult { Success = true };
    }
}

public class PayPalProcessor : IPaymentProcessor
{
    public PaymentResult Process(decimal amount)
    {
        Console.WriteLine("Processing PayPal payment");
        return new PaymentResult { Success = true };
    }
}

public class BitcoinProcessor : IPaymentProcessor
{
    public PaymentResult Process(decimal amount)
    {
        Console.WriteLine("Processing Bitcoin payment");
        return new PaymentResult { Success = true };
    }
}

// 3. Factory
public class PaymentProcessorFactory
{
    public IPaymentProcessor Create(string paymentType)
    {
        return paymentType.ToLower() switch
        {
            "creditcard" => new CreditCardProcessor(),
            "paypal" => new PayPalProcessor(),
            "bitcoin" => new BitcoinProcessor(),
            _ => throw new ArgumentException($"Unknown payment type: {paymentType}")
        };
    }
}

// Ishlatish
var factory = new PaymentProcessorFactory();
var processor = factory.Create("paypal");
var result = processor.Process(100.00m);
```

#### Abstract Factory Pattern

**Bir necha bog'liq obyektlar yaratish:**

```csharp
// Abstract factory
public interface IUIFactory
{
    IButton CreateButton();
    ITextBox CreateTextBox();
    ICheckbox CreateCheckbox();
}

// Concrete factory 1 - Windows UI
public class WindowsUIFactory : IUIFactory
{
    public IButton CreateButton() => new WindowsButton();
    public ITextBox CreateTextBox() => new WindowsTextBox();
    public ICheckbox CreateCheckbox() => new WindowsCheckbox();
}

// Concrete factory 2 - Mac UI
public class MacUIFactory : IUIFactory
{
    public IButton CreateButton() => new MacButton();
    public ITextBox CreateTextBox() => new MacTextBox();
    public ICheckbox CreateCheckbox() => new MacCheckbox();
}

// Ishlatish
IUIFactory factory;
if (OS.IsWindows)
    factory = new WindowsUIFactory();
else
    factory = new MacUIFactory();

var button = factory.CreateButton();
var textBox = factory.CreateTextBox();
// Barcha UI elementlari bir xil stilga ega
```

---

### 3. Builder Pattern

**Maqsad:** Murakkab obyektni qadam-baqadam qurish

**Qachon kerak?**
- Obyektda ko'p optional parametrlar
- Yaratish jarayoni murakkab

#### ❌ Muammo

```csharp
// Juda ko'p parametrlar!
var order = new Order(
    customerId: 123,
    items: itemsList,
    shippingAddress: address,
    billingAddress: billing,
    discount: 10,
    tax: 5,
    notes: "Handle with care",
    giftWrap: true,
    deliveryInstructions: "Leave at door",
    // ... 20+ parametr
);
```

#### ✅ Yechim

```csharp
// 1. Product
public class Order
{
    public int CustomerId { get; set; }
    public List<OrderItem> Items { get; set; }
    public Address ShippingAddress { get; set; }
    public Address BillingAddress { get; set; }
    public decimal Discount { get; set; }
    public decimal Tax { get; set; }
    public string Notes { get; set; }
    public bool GiftWrap { get; set; }
    public string DeliveryInstructions { get; set; }
}

// 2. Builder
public class OrderBuilder
{
    private readonly Order _order = new Order();
    
    public OrderBuilder ForCustomer(int customerId)
    {
        _order.CustomerId = customerId;
        return this;
    }
    
    public OrderBuilder WithItems(List<OrderItem> items)
    {
        _order.Items = items;
        return this;
    }
    
    public OrderBuilder ShipTo(Address address)
    {
        _order.ShippingAddress = address;
        return this;
    }
    
    public OrderBuilder BillTo(Address address)
    {
        _order.BillingAddress = address;
        return this;
    }
    
    public OrderBuilder WithDiscount(decimal discount)
    {
        _order.Discount = discount;
        return this;
    }
    
    public OrderBuilder WithTax(decimal tax)
    {
        _order.Tax = tax;
        return this;
    }
    
    public OrderBuilder WithNotes(string notes)
    {
        _order.Notes = notes;
        return this;
    }
    
    public OrderBuilder AsGiftWrapped()
    {
        _order.GiftWrap = true;
        return this;
    }
    
    public OrderBuilder WithDeliveryInstructions(string instructions)
    {
        _order.DeliveryInstructions = instructions;
        return this;
    }
    
    public Order Build()
    {
        // Validation
        if (_order.CustomerId == 0)
            throw new InvalidOperationException("Customer ID is required");
        if (_order.Items == null || !_order.Items.Any())
            throw new InvalidOperationException("Order must have items");
            
        return _order;
    }
}

// Ishlatish - Fluent API
var order = new OrderBuilder()
    .ForCustomer(123)
    .WithItems(itemsList)
    .ShipTo(shippingAddress)
    .BillTo(billingAddress)
    .WithDiscount(10)
    .AsGiftWrapped()
    .WithDeliveryInstructions("Leave at door")
    .Build();
```

**Afzalliklari:**
- ✅ O'qish oson
- ✅ Optional parametrlar
- ✅ Validation centralized
- ✅ Immutable obyektlar yaratish mumkin

---

### 4. Prototype Pattern

**Maqsad:** Mavjud obyektni klonlash

```csharp
public interface IPrototype<T>
{
    T Clone();
}

public class Product : IPrototype<Product>
{
    public string Name { get; set; }
    public decimal Price { get; set; }
    public Category Category { get; set; }
    
    public Product Clone()
    {
        return new Product
        {
            Name = this.Name,
            Price = this.Price,
            Category = this.Category.Clone() // Deep clone
        };
    }
}

// Ishlatish
var originalProduct = new Product 
{ 
    Name = "Laptop",
    Price = 1000 
};

var clonedProduct = originalProduct.Clone();
clonedProduct.Price = 900; // Original o'zgarmaydi
```

---

## STRUCTURAL PATTERNS

### 1. Adapter Pattern

**Maqsad:** Ikki mos kelmaydigan interface'ni birlashtiramish

**Misol:** Eski va yangi API'lar bilan ishlash

```csharp
// Yangi interface (bizning tizimimiz)
public interface IPaymentGateway
{
    PaymentResult Process(PaymentRequest request);
}

// Eski 3rd party library (o'zgartira olmaymiz)
public class LegacyPaymentService
{
    public bool MakePayment(string cardNumber, string cvv, double amount)
    {
        Console.WriteLine($"Legacy payment: {amount}");
        return true;
    }
}

// Adapter - Eski API'ni yangi interface'ga moslashtiradi
public class PaymentAdapter : IPaymentGateway
{
    private readonly LegacyPaymentService _legacyService;
    
    public PaymentAdapter(LegacyPaymentService legacyService)
    {
        _legacyService = legacyService;
    }
    
    public PaymentResult Process(PaymentRequest request)
    {
        // Yangi format -> Eski format
        bool success = _legacyService.MakePayment(
            request.CardNumber,
            request.CVV,
            (double)request.Amount
        );
        
        // Eski format -> Yangi format
        return new PaymentResult
        {
            Success = success,
            TransactionId = Guid.NewGuid().ToString()
        };
    }
}

// Ishlatish
IPaymentGateway gateway = new PaymentAdapter(new LegacyPaymentService());
var result = gateway.Process(new PaymentRequest
{
    CardNumber = "1234",
    CVV = "123",
    Amount = 100.00m
});
```

---

### 2. Decorator Pattern

**Maqsad:** Obyektga dinamik ravishda yangi funksionallik qo'shish (inheritance'siz)

**Misol:** Coffee shop

```csharp
// 1. Component interface
public interface ICoffee
{
    string GetDescription();
    decimal GetCost();
}

// 2. Concrete component
public class SimpleCoffee : ICoffee
{
    public string GetDescription() => "Simple coffee";
    public decimal GetCost() => 5.00m;
}

// 3. Base decorator
public abstract class CoffeeDecorator : ICoffee
{
    protected ICoffee _coffee;
    
    public CoffeeDecorator(ICoffee coffee)
    {
        _coffee = coffee;
    }
    
    public virtual string GetDescription() => _coffee.GetDescription();
    public virtual decimal GetCost() => _coffee.GetCost();
}

// 4. Concrete decorators
public class MilkDecorator : CoffeeDecorator
{
    public MilkDecorator(ICoffee coffee) : base(coffee) { }
    
    public override string GetDescription() => _coffee.GetDescription() + ", milk";
    public override decimal GetCost() => _coffee.GetCost() + 1.50m;
}

public class SugarDecorator : CoffeeDecorator
{
    public SugarDecorator(ICoffee coffee) : base(coffee) { }
    
    public override string GetDescription() => _coffee.GetDescription() + ", sugar";
    public override decimal GetCost() => _coffee.GetCost() + 0.50m;
}

public class WhipCreamDecorator : CoffeeDecorator
{
    public WhipCreamDecorator(ICoffee coffee) : base(coffee) { }
    
    public override string GetDescription() => _coffee.GetDescription() + ", whip cream";
    public override decimal GetCost() => _coffee.GetCost() + 2.00m;
}

// Ishlatish
ICoffee coffee = new SimpleCoffee();
Console.WriteLine($"{coffee.GetDescription()}: ${coffee.GetCost()}");
// Simple coffee: $5.00

coffee = new MilkDecorator(coffee);
Console.WriteLine($"{coffee.GetDescription()}: ${coffee.GetCost()}");
// Simple coffee, milk: $6.50

coffee = new SugarDecorator(coffee);
Console.WriteLine($"{coffee.GetDescription()}: ${coffee.GetCost()}");
// Simple coffee, milk, sugar: $7.00

coffee = new WhipCreamDecorator(coffee);
Console.WriteLine($"{coffee.GetDescription()}: ${coffee.GetCost()}");
// Simple coffee, milk, sugar, whip cream: $9.00
```

**Afzalliklari:**
- ✅ Runtime'da funksionallik qo'shish
- ✅ Bir necha decorator biriktirish
- ✅ Subclass yaratmasdan kengaytirish

---

### 3. Facade Pattern

**Maqsad:** Murakkab tizimga sodda interface yaratish

```csharp
// Murakkab subsystem'lar
public class InventoryService
{
    public bool CheckStock(int productId, int quantity)
    {
        Console.WriteLine("Checking stock...");
        return true;
    }
}

public class PaymentService
{
    public bool ProcessPayment(decimal amount)
    {
        Console.WriteLine("Processing payment...");
        return true;
    }
}

public class ShippingService
{
    public void ArrangeShipping(Order order)
    {
        Console.WriteLine("Arranging shipping...");
    }
}

public class NotificationService
{
    public void SendConfirmation(string email)
    {
        Console.WriteLine($"Sending confirmation to {email}");
    }
}

// Facade - Sodda interface
public class OrderFacade
{
    private readonly InventoryService _inventory;
    private readonly PaymentService _payment;
    private readonly ShippingService _shipping;
    private readonly NotificationService _notification;
    
    public OrderFacade()
    {
        _inventory = new InventoryService();
        _payment = new PaymentService();
        _shipping = new ShippingService();
        _notification = new NotificationService();
    }
    
    // Bitta sodda method - ichida murakkab logic
    public bool PlaceOrder(Order order)
    {
        Console.WriteLine("Starting order process...\n");
        
        // 1. Stock borligini tekshirish
        if (!_inventory.CheckStock(order.ProductId, order.Quantity))
        {
            Console.WriteLine("Out of stock!");
            return false;
        }
        
        // 2. To'lovni qayta ishlash
        if (!_payment.ProcessPayment(order.TotalAmount))
        {
            Console.WriteLine("Payment failed!");
            return false;
        }
        
        // 3. Yetkazib berishni tashkil qilish
        _shipping.ArrangeShipping(order);
        
        // 4. Tasdiqlash emailini yuborish
        _notification.SendConfirmation(order.CustomerEmail);
        
        Console.WriteLine("\nOrder placed successfully!");
        return true;
    }
}

// Ishlatish
var orderFacade = new OrderFacade();
var order = new Order 
{ 
    ProductId = 1, 
    Quantity = 2,
    TotalAmount = 100,
    CustomerEmail = "customer@example.com"
};

orderFacade.PlaceOrder(order); // Bitta method - hammasi avtomatik!
```

---

### 4. Proxy Pattern

**Maqsad:** Boshqa obyektga kirish nazoratini ta'minlash

**Turli proxy'lar:**
- Virtual Proxy - Lazy loading
- Protection Proxy - Access control
- Remote Proxy - Remote obyekt bilan ishlash

```csharp
// 1. Subject interface
public interface IDocument
{
    void Display();
}

// 2. Real subject - og'ir obyekt
public class RealDocument : IDocument
{
    private string _filename;
    private byte[] _content;
    
    public RealDocument(string filename)
    {
        _filename = filename;
        LoadFromDisk(); // Og'ir operatsiya!
    }
    
    private void LoadFromDisk()
    {
        Console.WriteLine($"Loading {_filename} from disk... (heavy operation)");
        Thread.Sleep(2000); // Simulate loading
        _content = new byte[1000000]; // 1MB
    }
    
    public void Display()
    {
        Console.WriteLine($"Displaying {_filename}");
    }
}

// 3. Proxy - Lazy loading
public class DocumentProxy : IDocument
{
    private string _filename;
    private RealDocument _realDocument;
    
    public DocumentProxy(string filename)
    {
        _filename = filename;
        // RealDocument hali yuklanmaydi!
    }
    
    public void Display()
    {
        // Lazy loading - faqat kerak bo'lganda yuklash
        if (_realDocument == null)
        {
            _realDocument = new RealDocument(_filename);
        }
        
        _realDocument.Display();
    }
}

// Ishlatish
Console.WriteLine("Creating proxy...");
IDocument doc = new DocumentProxy("large_file.pdf");
Console.WriteLine("Proxy created (file not loaded yet)\n");

Thread.Sleep(3000);

Console.WriteLine("Displaying document...");
doc.Display(); // Shu yerda yuklaydi
```

---

## BEHAVIORAL PATTERNS

### 1. Strategy Pattern

**Maqsad:** Algoritmlar oilasini almashtirish mumkin qilish

**Misol:** Sortlash algoritmlari

```csharp
// 1. Strategy interface
public interface ISortStrategy
{
    void Sort(List<int> list);
}

// 2. Concrete strategies
public class BubbleSortStrategy : ISortStrategy
{
    public void Sort(List<int> list)
    {
        Console.WriteLine("Sorting using bubble sort");
        // Bubble sort implementation
    }
}

public class QuickSortStrategy : ISortStrategy
{
    public void Sort(List<int> list)
    {
        Console.WriteLine("Sorting using quick sort");
        // Quick sort implementation
    }
}

public class MergeSortStrategy : ISortStrategy
{
    public void Sort(List<int> list)
    {
        Console.WriteLine("Sorting using merge sort");
        // Merge sort implementation
    }
}

// 3. Context
public class Sorter
{
    private ISortStrategy _strategy;
    
    public void SetStrategy(ISortStrategy strategy)
    {
        _strategy = strategy;
    }
    
    public void Sort(List<int> list)
    {
        _strategy.Sort(list);
    }
}

// Ishlatish
var sorter = new Sorter();
var numbers = new List<int> { 5, 2, 8, 1, 9 };

// Kichik list - bubble sort
if (numbers.Count < 10)
{
    sorter.SetStrategy(new BubbleSortStrategy());
}
// Katta list - quick sort
else
{
    sorter.SetStrategy(new QuickSortStrategy());
}

sorter.Sort(numbers);
```

---

### 2. Observer Pattern

**Maqsad:** Bir obyekt o'zgarganda, bog'liq obyektlarga xabar berish

**Misol:** Newsletter subscription

```csharp
// 1. Subject interface
public interface ISubject
{
    void Attach(IObserver observer);
    void Detach(IObserver observer);
    void Notify();
}

// 2. Observer interface
public interface IObserver
{
    void Update(string message);
}

// 3. Concrete subject
public class Newsletter : ISubject
{
    private List<IObserver> _observers = new List<IObserver>();
    private string _latestNews;
    
    public void Attach(IObserver observer)
    {
        _observers.Add(observer);
        Console.WriteLine("Observer attached");
    }
    
    public void Detach(IObserver observer)
    {
        _observers.Remove(observer);
        Console.WriteLine("Observer detached");
    }
    
    public void Notify()
    {
        foreach (var observer in _observers)
        {
            observer.Update(_latestNews);
        }
    }
    
    public void PublishNews(string news)
    {
        _latestNews = news;
        Console.WriteLine($"\nPublishing: {news}\n");
        Notify();
    }
}

// 4. Concrete observers
public class EmailSubscriber : IObserver
{
    private string _email;
    
    public EmailSubscriber(string email)
    {
        _email = email;
    }
    
    public void Update(string message)
    {
        Console.WriteLine($"Email sent to {_email}: {message}");
    }
}

public class SmsSubscriber : IObserver
{
    private string _phone;
    
    public SmsSubscriber(string phone)
    {
        _phone = phone;
    }
    
    public void Update(string message)
    {
        Console.WriteLine($"SMS sent to {_phone}: {message}");
    }
}

// Ishlatish
var newsletter = new Newsletter();

var subscriber1 = new EmailSubscriber("user1@example.com");
var subscriber2 = new EmailSubscriber("user2@example.com");
var subscriber3 = new SmsSubscriber("+998901234567");

newsletter.Attach(subscriber1);
newsletter.Attach(subscriber2);
newsletter.Attach(subscriber3);

newsletter.PublishNews("New product launched!");
// Email va SMS hamma subscriberlarga ketadi

newsletter.Detach(subscriber2);

newsletter.PublishNews("Sale starts tomorrow!");
// Faqat subscriber1 va subscriber3 xabar oladi
```

**C# da built-in Observer:**
```csharp
// Events bilan
public class Newsletter
{
    public event EventHandler<string> NewsPublished;
    
    public void PublishNews(string news)
    {
        NewsPublished?.Invoke(this, news);
    }
}

var newsletter = new Newsletter();
newsletter.NewsPublished += (sender, news) => 
    Console.WriteLine($"Email: {news}");
newsletter.NewsPublished += (sender, news) => 
    Console.WriteLine($"SMS: {news}");

newsletter.PublishNews("Breaking news!");
```

---

### 3. Command Pattern

**Maqsad:** Request'ni obyekt sifatida ifodalash

**Foydalari:**
- Undo/Redo funksiyasi
- Queue commands
- Log commands

```csharp
// 1. Command interface
public interface ICommand
{
    void Execute();
    void Undo();
}

// 2. Receiver
public class TextEditor
{
    private StringBuilder _content = new StringBuilder();
    
    public void AppendText(string text)
    {
        _content.Append(text);
        Console.WriteLine($"Text appended: {text}");
    }
    
    public void DeleteText(int length)
    {
        if (length > _content.Length)
            length = _content.Length;
            
        _content.Remove(_content.Length - length, length);
        Console.WriteLine($"Deleted {length} characters");
    }
    
    public string GetContent()
    {
        return _content.ToString();
    }
}

// 3. Concrete commands
public class AppendCommand : ICommand
{
    private readonly TextEditor _editor;
    private readonly string _text;
    
    public AppendCommand(TextEditor editor, string text)
    {
        _editor = editor;
        _text = text;
    }
    
    public void Execute()
    {
        _editor.AppendText(_text);
    }
    
    public void Undo()
    {
        _editor.DeleteText(_text.Length);
    }
}

// 4. Invoker
public class CommandManager
{
    private Stack<ICommand> _history = new Stack<ICommand>();
    
    public void ExecuteCommand(ICommand command)
    {
        command.Execute();
        _history.Push(command);
    }
    
    public void Undo()
    {
        if (_history.Count > 0)
        {
            var command = _history.Pop();
            command.Undo();
        }
    }
}

// Ishlatish
var editor = new TextEditor();
var manager = new CommandManager();

manager.ExecuteCommand(new AppendCommand(editor, "Hello "));
manager.ExecuteCommand(new AppendCommand(editor, "World"));
Console.WriteLine($"Content: {editor.GetContent()}");
// Content: Hello World

manager.Undo();
Console.WriteLine($"After undo: {editor.GetContent()}");
// After undo: Hello 

manager.Undo();
Console.WriteLine($"After undo: {editor.GetContent()}");
// After undo: (empty)
```

---

### 4. Template Method Pattern

**Maqsad:** Algoritmning skeletini belgilash, ba'zi qadamlarni subclass'larga qoldirish

```csharp
// 1. Abstract class - template
public abstract class DataProcessor
{
    // Template method - final qilib qo'yish yaxshi
    public void Process()
    {
        OpenFile();
        ExtractData();
        ParseData();
        AnalyzeData();
        SaveResults();
        CloseFile();
    }
    
    // Umumiy qadamlar
    private void OpenFile()
    {
        Console.WriteLine("Opening file...");
    }
    
    private void CloseFile()
    {
        Console.WriteLine("Closing file...");
    }
    
    private void SaveResults()
    {
        Console.WriteLine("Saving results...");
    }
    
    // Subclass'lar implement qilishi kerak
    protected abstract void ExtractData();
    protected abstract void ParseData();
    
    // Optional - subclass override qilishi mumkin
    protected virtual void AnalyzeData()
    {
        Console.WriteLine("Default analysis...");
    }
}

// 2. Concrete classes
public class CsvDataProcessor : DataProcessor
{
    protected override void ExtractData()
    {
        Console.WriteLine("Extracting CSV data...");
    }
    
    protected override void ParseData()
    {
        Console.WriteLine("Parsing CSV format...");
    }
}

public class JsonDataProcessor : DataProcessor
{
    protected override void ExtractData()
    {
        Console.WriteLine("Extracting JSON data...");
    }
    
    protected override void ParseData()
    {
        Console.WriteLine("Parsing JSON format...");
    }
    
    protected override void AnalyzeData()
    {
        Console.WriteLine("Advanced JSON analysis...");
    }
}

// Ishlatish
DataProcessor csvProcessor = new CsvDataProcessor();
csvProcessor.Process();

DataProcessor jsonProcessor = new JsonDataProcessor();
jsonProcessor.Process();
```

---

## Design Patterns Cheat Sheet

| Pattern | Maqsad | Qachon Ishlatish |
|---------|--------|------------------|
| **Singleton** | Bitta instance | Configuration, Logger |
| **Factory** | Obyekt yaratish logikasi | Qaysi class yaratish runtime'da aniqlanadi |
| **Builder** | Murakkab obyekt yaratish | Ko'p optional parametrlar |
| **Adapter** | Interface'larni moslashtirish | Eski API bilan ishlash |
| **Decorator** | Dinamik funksionallik qo'shish | Runtime'da xususiyatlar qo'shish |
| **Facade** | Sodda interface | Murakkab tizim |
| **Proxy** | Access control | Lazy loading, caching |
| **Strategy** | Algoritmlarni almashtirish | Turli xil xatti-harakatlar |
| **Observer** | Event handling | Bir o'zgarish ko'pga ta'sir qiladi |
| **Command** | Request'ni obyekt qilish | Undo/Redo, Queue |
| **Template Method** | Algoritm skeleti | Umumiy jarayon, turli implementatsiya |

---

## Anti-Patterns (Qilmaslik Kerak!)

### 1. God Object
```csharp
// ❌ Bitta class hammani qiladi
public class Application
{
    public void ValidateUser() { }
    public void ProcessPayment() { }
    public void SendEmail() { }
    public void GenerateReport() { }
    // ... 100+ method
}
```

### 2. Spaghetti Code
```csharp
// ❌ Goto, uzoq method'lar, if ichida if
public void Process()
{
    if (condition1)
    {
        if (condition2)
        {
            if (condition3)
            {
                // ... 10 level ichida
            }
        }
    }
}
```

### 3. Copy-Paste Programming
```csharp
// ❌ Bir xil kod ko'p joyda
public void ProcessOrder1() { /* kod */ }
public void ProcessOrder2() { /* bir xil kod */ }
public void ProcessOrder3() { /* bir xil kod */ }
```

---

## Amaliy Mashq

E-commerce tizimi uchun quyidagi pattern'larni qo'llang:

1. **Factory** - PaymentProcessor yaratish
2. **Strategy** - Shipping cost hisoblash (Standard, Express, Overnight)
3. **Observer** - Order status o'zgarganda notification
4. **Decorator** - Gift wrapping, insurance qo'shish
5. **Facade** - Checkout jarayoni

---

## Keyingi Qadamlar

Design Patterns'ni o'zgandingiz! Endi:

1. **Domain-Driven Design (DDD)** - Murakkab biznes logikani modellash
2. **Microservices Patterns** - Distributed tizimlar
3. **Testing Patterns** - Yaxshi testlar yozish

Keyingi bo'lim: [Domain-Driven Design](./04-domain-driven-design.md)
