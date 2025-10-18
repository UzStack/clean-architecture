# Clean Architecture - To'liq Qo'llanma

## Clean Architecture Nima?

Clean Architecture - bu Robert C. Martin (Uncle Bob) tomonidan taklif qilingan dasturiy ta'minot arxitektura yondashuvi bo'lib, kodni:
- Mustaqil (Independent)
- Testlanuvchi (Testable)
- O'zgartirishga oson (Maintainable)
- Framework'lardan mustaqil

qilishga qaratilgan.

---

## Asosiy Prinsiplar

### 1. Dependency Rule (Bog'liqlik Qoidasi)

**Qoida:** Kodning ichki qatlamlari tashqi qatlamlar haqida hech narsa bilmasligi kerak.

```
Tashqi → Ichki yo'nalishda bog'liqlik BO'LISHI MUMKIN
Ichki → Tashqi yo'nalishda bog'liqlik BO'LMASLIGI KERAK
```

**Nima uchun muhim?**
- Business logika framework'dan mustaqil bo'ladi
- Ma'lumotlar bazasini almashtirish oson
- Testing oson
- Kodning qayta ishlatilishi yuqori

---

## Clean Architecture Qatlamlari

### Umumiy Struktura (Ichkari → Tashqi):

```
┌─────────────────────────────────────────┐
│     4. Frameworks & Drivers             │  ← Database, Web, UI
│  ┌───────────────────────────────────┐  │
│  │   3. Interface Adapters           │  │  ← Controllers, Gateways
│  │  ┌─────────────────────────────┐  │  │
│  │  │  2. Application Business    │  │  │  ← Use Cases
│  │  │     Rules                   │  │  │
│  │  │  ┌───────────────────────┐  │  │  │
│  │  │  │ 1. Enterprise        │  │  │  │  ← Entities
│  │  │  │    Business Rules    │  │  │  │
│  │  │  └───────────────────────┘  │  │  │
│  │  └─────────────────────────────┘  │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘

Bog'liqlik yo'nalishi: Tashqi → Ichki (faqat bir tomonlama)
```

---

## 1. Entities (Enterprise Business Rules)

**Bu nima?**
- Biznesning eng asosiy qoidalarini o'z ichiga oladi
- Framework, database va boshqa tashqi narsalardan mutlaqo mustaqil
- Butun tashkilot bo'ylab umumiy bo'lgan qoidalar

### Misol: E-commerce Tizimi

```csharp
// Entities/Order.cs
public class Order
{
    public Guid Id { get; private set; }
    public DateTime CreatedAt { get; private set; }
    public OrderStatus Status { get; private set; }
    private List<OrderItem> _items = new();
    public IReadOnlyList<OrderItem> Items => _items.AsReadOnly();
    
    // Business logic - hech qaysi tashqi narsaga bog'liq emas
    public decimal CalculateTotal()
    {
        return _items.Sum(item => item.Price * item.Quantity);
    }
    
    public void AddItem(Product product, int quantity)
    {
        // Business rule: Quantity 0 dan katta bo'lishi kerak
        if (quantity <= 0)
            throw new InvalidOperationException("Quantity must be greater than 0");
            
        // Business rule: Bir xil mahsulotni ikki marta qo'shib bo'lmaydi
        if (_items.Any(i => i.ProductId == product.Id))
            throw new InvalidOperationException("Product already in order");
            
        _items.Add(new OrderItem(product.Id, product.Name, product.Price, quantity));
    }
    
    public void Confirm()
    {
        // Business rule: Bo'sh buyurtmani tasdiqlash mumkin emas
        if (!_items.Any())
            throw new InvalidOperationException("Cannot confirm empty order");
            
        // Business rule: Faqat Draft holatdagi buyurtmani tasdiqlash mumkin
        if (Status != OrderStatus.Draft)
            throw new InvalidOperationException("Only draft orders can be confirmed");
            
        Status = OrderStatus.Confirmed;
    }
    
    public void Cancel()
    {
        // Business rule: Yetkazilgan buyurtmani bekor qilib bo'lmaydi
        if (Status == OrderStatus.Delivered)
            throw new InvalidOperationException("Cannot cancel delivered order");
            
        Status = OrderStatus.Cancelled;
    }
}

public class OrderItem
{
    public Guid ProductId { get; private set; }
    public string ProductName { get; private set; }
    public decimal Price { get; private set; }
    public int Quantity { get; private set; }
    
    public OrderItem(Guid productId, string name, decimal price, int quantity)
    {
        ProductId = productId;
        ProductName = name;
        Price = price;
        Quantity = quantity;
    }
}

public enum OrderStatus
{
    Draft,
    Confirmed,
    Shipped,
    Delivered,
    Cancelled
}
```

**Entities ning xususiyatlari:**
- ✅ Hech qanday tashqi kutubxonaga bog'liq emas
- ✅ Pure C# kodi
- ✅ Business qoidalari aniq ko'rinadi
- ✅ Oson test qilish mumkin
- ✅ Qayta ishlatish mumkin

---

## 2. Use Cases (Application Business Rules)

**Bu nima?**
- Dastur qanday ishlashini belgilaydi
- Biznes jarayonlarini boshqaradi (orchestration)
- Entity'lardan foydalanadi

### Misol: Buyurtma Yaratish Use Case

```csharp
// UseCases/CreateOrder/CreateOrderUseCase.cs
public class CreateOrderUseCase : ICreateOrderUseCase
{
    private readonly IOrderRepository _orderRepository;
    private readonly IProductRepository _productRepository;
    private readonly IUnitOfWork _unitOfWork;
    
    public CreateOrderUseCase(
        IOrderRepository orderRepository,
        IProductRepository productRepository,
        IUnitOfWork unitOfWork)
    {
        _orderRepository = orderRepository;
        _productRepository = productRepository;
        _unitOfWork = unitOfWork;
    }
    
    public async Task<CreateOrderResponse> ExecuteAsync(CreateOrderRequest request)
    {
        // 1. Validation
        if (request.Items == null || !request.Items.Any())
            throw new ValidationException("Order must have at least one item");
        
        // 2. Mahsulotlarni olish
        var productIds = request.Items.Select(i => i.ProductId).ToList();
        var products = await _productRepository.GetByIdsAsync(productIds);
        
        // 3. Barcha mahsulotlar mavjudligini tekshirish
        if (products.Count != productIds.Count)
            throw new ValidationException("Some products not found");
        
        // 4. Order entity yaratish
        var order = new Order();
        
        foreach (var item in request.Items)
        {
            var product = products.First(p => p.Id == item.ProductId);
            
            // Stock borligini tekshirish
            if (product.Stock < item.Quantity)
                throw new ValidationException($"Insufficient stock for {product.Name}");
                
            order.AddItem(product, item.Quantity);
            
            // Stock ni kamaytirish
            product.DecreaseStock(item.Quantity);
        }
        
        // 5. Buyurtmani saqlash
        await _orderRepository.AddAsync(order);
        await _unitOfWork.CommitAsync();
        
        // 6. Response qaytarish
        return new CreateOrderResponse
        {
            OrderId = order.Id,
            TotalAmount = order.CalculateTotal(),
            Status = order.Status.ToString()
        };
    }
}

// UseCases/CreateOrder/ICreateOrderUseCase.cs
public interface ICreateOrderUseCase
{
    Task<CreateOrderResponse> ExecuteAsync(CreateOrderRequest request);
}

// UseCases/CreateOrder/CreateOrderRequest.cs
public class CreateOrderRequest
{
    public List<OrderItemRequest> Items { get; set; }
}

public class OrderItemRequest
{
    public Guid ProductId { get; set; }
    public int Quantity { get; set; }
}

// UseCases/CreateOrder/CreateOrderResponse.cs
public class CreateOrderResponse
{
    public Guid OrderId { get; set; }
    public decimal TotalAmount { get; set; }
    public string Status { get; set; }
}
```

**Use Case ning xususiyatlari:**
- ✅ Bitta biznes vazifani bajaradi
- ✅ Interface'lar orqali tashqi qatlamlar bilan ishlaydi
- ✅ Framework'dan mustaqil
- ✅ Oson test qilish mumkin

---

## 3. Interface Adapters

**Bu nima?**
- Use Case'lar va tashqi dunyo o'rtasida ko'prik
- Ma'lumotlarni bir formatdan ikkinchisiga o'giradi
- Controllers, Presenters, Gateways

### Misol: Controller

```csharp
// Controllers/OrdersController.cs
[ApiController]
[Route("api/[controller]")]
public class OrdersController : ControllerBase
{
    private readonly ICreateOrderUseCase _createOrderUseCase;
    private readonly IGetOrderUseCase _getOrderUseCase;
    
    public OrdersController(
        ICreateOrderUseCase createOrderUseCase,
        IGetOrderUseCase getOrderUseCase)
    {
        _createOrderUseCase = createOrderUseCase;
        _getOrderUseCase = getOrderUseCase;
    }
    
    [HttpPost]
    public async Task<IActionResult> CreateOrder([FromBody] CreateOrderDto dto)
    {
        try
        {
            // DTO -> Request (Web format -> Use Case format)
            var request = new CreateOrderRequest
            {
                Items = dto.Items.Select(i => new OrderItemRequest
                {
                    ProductId = i.ProductId,
                    Quantity = i.Quantity
                }).ToList()
            };
            
            // Use Case'ni chaqirish
            var response = await _createOrderUseCase.ExecuteAsync(request);
            
            // Response -> DTO (Use Case format -> Web format)
            var resultDto = new OrderCreatedDto
            {
                OrderId = response.OrderId,
                Total = response.TotalAmount,
                Status = response.Status
            };
            
            return CreatedAtAction(nameof(GetOrder), new { id = resultDto.OrderId }, resultDto);
        }
        catch (ValidationException ex)
        {
            return BadRequest(new { error = ex.Message });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = "Internal server error" });
        }
    }
    
    [HttpGet("{id}")]
    public async Task<IActionResult> GetOrder(Guid id)
    {
        var response = await _getOrderUseCase.ExecuteAsync(new GetOrderRequest { OrderId = id });
        
        if (response == null)
            return NotFound();
            
        return Ok(response);
    }
}

// DTOs/CreateOrderDto.cs
public class CreateOrderDto
{
    public List<OrderItemDto> Items { get; set; }
}

public class OrderItemDto
{
    public Guid ProductId { get; set; }
    public int Quantity { get; set; }
}

public class OrderCreatedDto
{
    public Guid OrderId { get; set; }
    public decimal Total { get; set; }
    public string Status { get; set; }
}
```

### Misol: Repository Implementation

```csharp
// Infrastructure/Persistence/Repositories/OrderRepository.cs
public class OrderRepository : IOrderRepository
{
    private readonly ApplicationDbContext _context;
    
    public OrderRepository(ApplicationDbContext context)
    {
        _context = context;
    }
    
    public async Task<Order> GetByIdAsync(Guid id)
    {
        // Database model'dan Domain entity'ga o'girish
        var orderDb = await _context.Orders
            .Include(o => o.Items)
            .FirstOrDefaultAsync(o => o.Id == id);
            
        if (orderDb == null)
            return null;
            
        return MapToDomain(orderDb);
    }
    
    public async Task AddAsync(Order order)
    {
        // Domain entity'dan Database model'ga o'girish
        var orderDb = MapToDatabase(order);
        await _context.Orders.AddAsync(orderDb);
    }
    
    private Order MapToDomain(OrderDb orderDb)
    {
        // Database model -> Domain entity
        var order = new Order(orderDb.Id, orderDb.CreatedAt);
        
        foreach (var item in orderDb.Items)
        {
            order.AddItem(
                new Product(item.ProductId, item.ProductName, item.Price),
                item.Quantity
            );
        }
        
        return order;
    }
    
    private OrderDb MapToDatabase(Order order)
    {
        // Domain entity -> Database model
        return new OrderDb
        {
            Id = order.Id,
            CreatedAt = order.CreatedAt,
            Status = order.Status.ToString(),
            Items = order.Items.Select(i => new OrderItemDb
            {
                ProductId = i.ProductId,
                ProductName = i.ProductName,
                Price = i.Price,
                Quantity = i.Quantity
            }).ToList()
        };
    }
}
```

---

## 4. Frameworks & Drivers

**Bu nima?**
- Eng tashqi qatlam
- Database, Web framework, UI
- Konfiguratsiya va glue code

### Misol: Database Configuration

```csharp
// Infrastructure/Persistence/ApplicationDbContext.cs
public class ApplicationDbContext : DbContext
{
    public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
        : base(options)
    {
    }
    
    public DbSet<OrderDb> Orders { get; set; }
    public DbSet<ProductDb> Products { get; set; }
    
    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        // Order configuration
        modelBuilder.Entity<OrderDb>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Status).HasMaxLength(50);
            entity.HasMany(e => e.Items)
                  .WithOne()
                  .HasForeignKey("OrderId");
        });
        
        // Product configuration
        modelBuilder.Entity<ProductDb>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Name).HasMaxLength(200);
            entity.Property(e => e.Price).HasColumnType("decimal(18,2)");
        });
    }
}

// Infrastructure/Persistence/Models/OrderDb.cs
public class OrderDb
{
    public Guid Id { get; set; }
    public DateTime CreatedAt { get; set; }
    public string Status { get; set; }
    public List<OrderItemDb> Items { get; set; }
}

public class OrderItemDb
{
    public int Id { get; set; }
    public Guid ProductId { get; set; }
    public string ProductName { get; set; }
    public decimal Price { get; set; }
    public int Quantity { get; set; }
}
```

### Misol: Dependency Injection Setup

```csharp
// Program.cs yoki Startup.cs
public class Program
{
    public static void Main(string[] args)
    {
        var builder = WebApplication.CreateBuilder(args);
        
        // Infrastructure layer
        builder.Services.AddDbContext<ApplicationDbContext>(options =>
            options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));
        
        // Repositories
        builder.Services.AddScoped<IOrderRepository, OrderRepository>();
        builder.Services.AddScoped<IProductRepository, ProductRepository>();
        builder.Services.AddScoped<IUnitOfWork, UnitOfWork>();
        
        // Use Cases
        builder.Services.AddScoped<ICreateOrderUseCase, CreateOrderUseCase>();
        builder.Services.AddScoped<IGetOrderUseCase, GetOrderUseCase>();
        
        // Controllers
        builder.Services.AddControllers();
        
        var app = builder.Build();
        
        app.MapControllers();
        app.Run();
    }
}
```

---

## Dependency Inversion Principle

**Muammo:** Use Case database haqida bilmasligi kerak, lekin unga kerak.

**Yechim:** Interface ishlatish!

```csharp
// Use Cases qatlamida interface e'lon qilamiz
public interface IOrderRepository
{
    Task<Order> GetByIdAsync(Guid id);
    Task AddAsync(Order order);
}

// Use Case interface'ga bog'liq
public class CreateOrderUseCase
{
    private readonly IOrderRepository _repository; // Interface!
    
    public CreateOrderUseCase(IOrderRepository repository)
    {
        _repository = repository; // Concrete class emas, interface
    }
}

// Infrastructure qatlamida interface'ni implement qilamiz
public class OrderRepository : IOrderRepository
{
    // SQL Server implementation
}

// Yoki boshqa implementation
public class MongoOrderRepository : IOrderRepository
{
    // MongoDB implementation
}
```

**Natija:**
- Use Case database haqida bilmaydi
- Database'ni osongina almashtirish mumkin
- Test qilishda mock/stub ishlatish mumkin

---

## Folder Structure

```
MyProject/
├── src/
│   ├── Domain/                          # Entities qatlami
│   │   ├── Entities/
│   │   │   ├── Order.cs
│   │   │   ├── Product.cs
│   │   │   └── Customer.cs
│   │   ├── ValueObjects/
│   │   │   ├── Money.cs
│   │   │   └── Address.cs
│   │   └── Exceptions/
│   │       └── DomainException.cs
│   │
│   ├── Application/                     # Use Cases qatlami
│   │   ├── UseCases/
│   │   │   ├── Orders/
│   │   │   │   ├── CreateOrder/
│   │   │   │   │   ├── CreateOrderUseCase.cs
│   │   │   │   │   ├── ICreateOrderUseCase.cs
│   │   │   │   │   ├── CreateOrderRequest.cs
│   │   │   │   │   └── CreateOrderResponse.cs
│   │   │   │   └── GetOrder/
│   │   │   └── Products/
│   │   ├── Interfaces/                  # Repository interfaces
│   │   │   ├── IOrderRepository.cs
│   │   │   ├── IProductRepository.cs
│   │   │   └── IUnitOfWork.cs
│   │   └── Common/
│   │       └── ValidationException.cs
│   │
│   ├── Infrastructure/                  # Frameworks & Drivers
│   │   ├── Persistence/
│   │   │   ├── ApplicationDbContext.cs
│   │   │   ├── Models/
│   │   │   │   ├── OrderDb.cs
│   │   │   │   └── ProductDb.cs
│   │   │   └── Repositories/
│   │   │       ├── OrderRepository.cs
│   │   │       └── ProductRepository.cs
│   │   ├── ExternalServices/
│   │   │   ├── EmailService.cs
│   │   │   └── PaymentService.cs
│   │   └── Configuration/
│   │
│   └── WebApi/                          # Interface Adapters
│       ├── Controllers/
│       │   ├── OrdersController.cs
│       │   └── ProductsController.cs
│       ├── DTOs/
│       │   ├── CreateOrderDto.cs
│       │   └── OrderResponseDto.cs
│       ├── Middleware/
│       │   └── ExceptionHandlingMiddleware.cs
│       └── Program.cs
│
└── tests/
    ├── Domain.Tests/
    ├── Application.Tests/
    └── WebApi.Tests/
```

---

## Afzalliklari

### 1. **Framework Mustaqilligi**

```csharp
// Eski kod - Framework'ga bog'liq
public class OrderService
{
    public void CreateOrder(HttpRequest request)
    {
        var data = request.Form["orderData"];
        // ASP.NET'ga bog'liq kod
    }
}

// Clean Architecture - Framework'dan mustaqil
public class CreateOrderUseCase
{
    public async Task<CreateOrderResponse> ExecuteAsync(CreateOrderRequest request)
    {
        // Framework haqida bilmaydi
        // Faqat biznes logika
    }
}
```

### 2. **Database Mustaqilligi**

```csharp
// Use Case database turini bilmaydi
public class CreateOrderUseCase
{
    private readonly IOrderRepository _repository; // Interface
    
    // SQL Server, MongoDB, Memory - farqi yo'q!
}
```

### 3. **Testlanuvchanlik**

```csharp
[Test]
public async Task CreateOrder_WithValidData_ShouldSucceed()
{
    // Arrange
    var mockRepository = new Mock<IOrderRepository>();
    var mockUnitOfWork = new Mock<IUnitOfWork>();
    var useCase = new CreateOrderUseCase(
        mockRepository.Object,
        mockUnitOfWork.Object
    );
    
    // Act
    var result = await useCase.ExecuteAsync(new CreateOrderRequest
    {
        Items = new List<OrderItemRequest>
        {
            new OrderItemRequest { ProductId = Guid.NewGuid(), Quantity = 2 }
        }
    });
    
    // Assert
    Assert.IsNotNull(result);
    mockRepository.Verify(r => r.AddAsync(It.IsAny<Order>()), Times.Once);
}
```

### 4. **UI Mustaqilligi**

```csharp
// Bir xil Use Case
// - Web API'dan
// - Console application'dan
// - Desktop app'dan
// - Mobile app'dan
// ishlashi mumkin!
```

---

## Keng Tarqalgan Xatolar

### ❌ Xato 1: Entity'da Database Logic

```csharp
// NOTO'G'RI
public class Order
{
    public void Save()
    {
        using (var db = new DbContext())
        {
            db.Orders.Add(this);
            db.SaveChanges();
        }
    }
}
```

**To'g'risi:**
```csharp
// TO'G'RI
public class Order
{
    // Faqat business logic
    public void AddItem(Product product, int quantity) { }
    public decimal CalculateTotal() { }
}

// Repository'da persistence logic
public class OrderRepository : IOrderRepository
{
    public async Task AddAsync(Order order)
    {
        await _context.Orders.AddAsync(MapToDb(order));
    }
}
```

### ❌ Xato 2: Use Case'da HTTP Logic

```csharp
// NOTO'G'RI
public class CreateOrderUseCase
{
    public IActionResult Execute(HttpRequest request)
    {
        // HTTP ga bog'liq
        var data = request.Form["data"];
        return new OkResult();
    }
}
```

**To'g'risi:**
```csharp
// TO'G'RI
public class CreateOrderUseCase
{
    public async Task<CreateOrderResponse> ExecuteAsync(CreateOrderRequest request)
    {
        // HTTP haqida bilmaydi
        // Faqat request va response obyektlari
    }
}
```

### ❌ Xato 3: Dependency Rule Buzilishi

```csharp
// NOTO'G'RI - Use Case Controller'ni biladi
public class CreateOrderUseCase
{
    private readonly OrdersController _controller; // ❌
}
```

**To'g'risi:**
```csharp
// TO'G'RI - Controller Use Case'ni biladi
public class OrdersController
{
    private readonly ICreateOrderUseCase _useCase; // ✅
}
```

---

## Qachon Ishlatish Kerak?

### ✅ Ishlating:
- Katta va murakkab loyihalarda
- Uzoq muddatli loyihalarda
- Team bilan ishlashda
- Biznes logika murakkab bo'lganda
- Testing muhim bo'lganda

### ❌ Ishlatmang:
- Oddiy CRUD applicationlarda
- Prototiplarda
- Minimal MVP larda
- Juda kichik loyihalarda

---

## Amaliy Mashq

Quyidagi tizimni Clean Architecture bilan yozing:

**Vazifa:** Kutubxona Tizimi

**Talablar:**
1. Kitob qo'shish/o'chirish/tahrirlash
2. Kitobni ijaraga berish
3. Kitobni qaytarish
4. Kechikkan kitoblar uchun jarima hisoblash
5. Foydalanuvchi registratsiyasi

**Business Qoidalar:**
- Kitobni maksimum 14 kunga ijaraga berish mumkin
- Bir foydalanuvchi maksimum 5 ta kitob olishi mumkin
- Har bir kechikkan kun uchun 5000 so'm jarima
- Jarimasi bo'lgan foydalanuvchi yangi kitob ololmaydi

**Topshiriq:**
1. Entities yarating
2. Use Case'lar yozing
3. Interface'lar belgilang
4. Folder structure yarating

---

## Keyingi Bosqich

Clean Architecture'ni o'rgandingiz! Endi quyidagilarni o'rganing:

1. **SOLID Principles** - Clean Architecture'ning asosi
2. **Design Patterns** - Umumiy muammolarga tayyor yechimlar
3. **Domain-Driven Design** - Murakkab domain'lar bilan ishlash
4. **Testing Strategies** - Clean Architecture'ni test qilish

Keyingi bo'limga o'ting: [SOLID Prinsiplari](./02-solid-principles.md)
