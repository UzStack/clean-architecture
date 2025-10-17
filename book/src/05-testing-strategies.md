# Testing Strategiyalari - To'liq Qo'llanma

Senior developer sifatida testing juda muhim! Test yozish - bu kodingizning ishonchliligini kafolatlashdir.

---

## Testing Pyramid

```
           ╱╲
          ╱  ╲         E2E Tests (5%)
         ╱────╲        - UI tests
        ╱      ╲       - Integration tests
       ╱────────╲      
      ╱          ╲     Integration Tests (15%)
     ╱────────────╲    - API tests
    ╱              ╲   - Database tests
   ╱────────────────╲  
  ╱                  ╲ Unit Tests (80%)
 ╱────────────────────╲ - Business logic
╱______________________╲ - Pure functions
```

**Qoida:** Ko'proq unit test, kamroq integration test, eng kam E2E test.

---

## 1. Unit Testing

**Maqsad:** Alohida komponetlarni test qilish

### Yaxshi Unit Test'ning Xususiyatlari

1. **F**ast - Tez ishlaydi
2. **I**solated - Boshqa testlardan mustaqil
3. **R**epeatable - Har safar bir xil natija
4. **S**elf-validating - O'zi tekshiradi (manual emas)
5. **T**imely - Kod bilan birga yoziladi

### Misol: Calculator Test

```csharp
// xUnit framework
public class CalculatorTests
{
    [Fact]
    public void Add_TwoPositiveNumbers_ReturnsSum()
    {
        // Arrange - Tayyorgarlik
        var calculator = new Calculator();
        int a = 5;
        int b = 3;
        
        // Act - Harakat
        int result = calculator.Add(a, b);
        
        // Assert - Tekshirish
        Assert.Equal(8, result);
    }
    
    [Theory]
    [InlineData(5, 3, 8)]
    [InlineData(-5, 3, -2)]
    [InlineData(0, 0, 0)]
    [InlineData(100, -50, 50)]
    public void Add_VariousNumbers_ReturnsCorrectSum(int a, int b, int expected)
    {
        // Arrange
        var calculator = new Calculator();
        
        // Act
        int result = calculator.Add(a, b);
        
        // Assert
        Assert.Equal(expected, result);
    }
    
    [Fact]
    public void Divide_ByZero_ThrowsException()
    {
        // Arrange
        var calculator = new Calculator();
        
        // Act & Assert
        Assert.Throws<DivideByZeroException>(() => 
            calculator.Divide(10, 0));
    }
}
```

### Testing Domain Logic

```csharp
public class OrderTests
{
    [Fact]
    public void AddItem_ToValidOrder_IncreaseItemCount()
    {
        // Arrange
        var order = new Order(OrderId.New(), CustomerId.New());
        var product = new Product("Laptop", Money.FromDecimal(1000, "USD"));
        
        // Act
        order.AddItem(product, 2);
        
        // Assert
        Assert.Single(order.Items);
        Assert.Equal(2, order.Items.First().Quantity);
        Assert.Equal(Money.FromDecimal(2000, "USD"), order.TotalAmount);
    }
    
    [Fact]
    public void Confirm_EmptyOrder_ThrowsException()
    {
        // Arrange
        var order = new Order(OrderId.New(), CustomerId.New());
        
        // Act & Assert
        var exception = Assert.Throws<DomainException>(() => order.Confirm());
        Assert.Equal("Cannot confirm empty order", exception.Message);
    }
    
    [Fact]
    public void Confirm_ValidOrder_ChangesStatusToConfirmed()
    {
        // Arrange
        var order = new Order(OrderId.New(), CustomerId.New());
        var product = new Product("Laptop", Money.FromDecimal(1000, "USD"));
        order.AddItem(product, 1);
        
        // Act
        order.Confirm();
        
        // Assert
        Assert.Equal(OrderStatus.Confirmed, order.Status);
    }
    
    [Fact]
    public void Confirm_AlreadyConfirmedOrder_ThrowsException()
    {
        // Arrange
        var order = new Order(OrderId.New(), CustomerId.New());
        var product = new Product("Laptop", Money.FromDecimal(1000, "USD"));
        order.AddItem(product, 1);
        order.Confirm();
        
        // Act & Assert
        Assert.Throws<DomainException>(() => order.Confirm());
    }
}
```

---

## 2. Mocking va Stubbing

**Muammo:** Dependency'larga bog'liq kod'ni qanday test qilish?

### Moq Framework

```csharp
public class OrderServiceTests
{
    [Fact]
    public async Task CreateOrder_ValidRequest_SavesOrder()
    {
        // Arrange
        var mockRepository = new Mock<IOrderRepository>();
        var mockUnitOfWork = new Mock<IUnitOfWork>();
        var mockProductRepository = new Mock<IProductRepository>();
        
        var product = new Product(ProductId.New(), "Laptop", Money.FromDecimal(1000, "USD"));
        mockProductRepository
            .Setup(r => r.GetByIdAsync(It.IsAny<ProductId>()))
            .ReturnsAsync(product);
        
        var service = new OrderService(
            mockRepository.Object,
            mockProductRepository.Object,
            mockUnitOfWork.Object
        );
        
        var request = new CreateOrderRequest
        {
            CustomerId = CustomerId.New(),
            Items = new List<OrderItemRequest>
            {
                new() { ProductId = product.Id, Quantity = 2 }
            }
        };
        
        // Act
        var result = await service.CreateOrderAsync(request);
        
        // Assert
        Assert.NotNull(result);
        mockRepository.Verify(
            r => r.AddAsync(It.IsAny<Order>()), 
            Times.Once
        );
        mockUnitOfWork.Verify(
            u => u.CommitAsync(), 
            Times.Once
        );
    }
    
    [Fact]
    public async Task CreateOrder_ProductNotFound_ThrowsException()
    {
        // Arrange
        var mockRepository = new Mock<IOrderRepository>();
        var mockProductRepository = new Mock<IProductRepository>();
        
        mockProductRepository
            .Setup(r => r.GetByIdAsync(It.IsAny<ProductId>()))
            .ReturnsAsync((Product)null); // Product topilmadi
        
        var service = new OrderService(
            mockRepository.Object,
            mockProductRepository.Object,
            Mock.Of<IUnitOfWork>()
        );
        
        var request = new CreateOrderRequest
        {
            Items = new List<OrderItemRequest>
            {
                new() { ProductId = ProductId.New(), Quantity = 1 }
            }
        };
        
        // Act & Assert
        await Assert.ThrowsAsync<NotFoundException>(
            () => service.CreateOrderAsync(request)
        );
    }
}
```

### Mock vs Stub vs Fake

```csharp
// MOCK - Verify qilish uchun
var mockEmailService = new Mock<IEmailService>();
mockEmailService.Setup(s => s.SendAsync(It.IsAny<string>(), It.IsAny<string>()));

// Ishlatish
await service.RegisterUserAsync(request);

// Verify - chaqirilganligini tekshirish
mockEmailService.Verify(
    s => s.SendAsync("user@example.com", It.IsAny<string>()), 
    Times.Once
);

// STUB - Ma'lumot qaytarish uchun
var stubRepository = new Mock<IUserRepository>();
stubRepository
    .Setup(r => r.GetByIdAsync(It.IsAny<UserId>()))
    .ReturnsAsync(new User(UserId.New(), "Test User"));

// FAKE - To'liq ishlaydigan test implementation
public class FakeOrderRepository : IOrderRepository
{
    private List<Order> _orders = new();
    
    public Task<Order> GetByIdAsync(OrderId id)
    {
        var order = _orders.FirstOrDefault(o => o.Id == id);
        return Task.FromResult(order);
    }
    
    public Task AddAsync(Order order)
    {
        _orders.Add(order);
        return Task.CompletedTask;
    }
}
```

---

## 3. Integration Testing

**Maqsad:** Bir necha komponentlarning birga ishlashini tekshirish

### Database Integration Test

```csharp
public class OrderRepositoryIntegrationTests : IDisposable
{
    private readonly ApplicationDbContext _context;
    private readonly OrderRepository _repository;
    
    public OrderRepositoryIntegrationTests()
    {
        // In-memory database
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
            
        _context = new ApplicationDbContext(options);
        _repository = new OrderRepository(_context);
    }
    
    [Fact]
    public async Task AddAsync_ValidOrder_SavesSuccessfully()
    {
        // Arrange
        var order = new Order(OrderId.New(), CustomerId.New());
        var product = new Product(ProductId.New(), "Laptop", Money.FromDecimal(1000, "USD"));
        order.AddItem(product, 2);
        
        // Act
        await _repository.AddAsync(order);
        await _context.SaveChangesAsync();
        
        // Assert
        var savedOrder = await _repository.GetByIdAsync(order.Id);
        Assert.NotNull(savedOrder);
        Assert.Equal(order.Id, savedOrder.Id);
        Assert.Single(savedOrder.Items);
    }
    
    [Fact]
    public async Task GetByCustomerIdAsync_ReturnsCustomerOrders()
    {
        // Arrange
        var customerId = CustomerId.New();
        
        var order1 = new Order(OrderId.New(), customerId);
        var order2 = new Order(OrderId.New(), customerId);
        var order3 = new Order(OrderId.New(), CustomerId.New()); // Boshqa customer
        
        await _repository.AddAsync(order1);
        await _repository.AddAsync(order2);
        await _repository.AddAsync(order3);
        await _context.SaveChangesAsync();
        
        // Act
        var orders = await _repository.GetByCustomerIdAsync(customerId);
        
        // Assert
        Assert.Equal(2, orders.Count);
        Assert.All(orders, o => Assert.Equal(customerId, o.CustomerId));
    }
    
    public void Dispose()
    {
        _context.Database.EnsureDeleted();
        _context.Dispose();
    }
}
```

### API Integration Test

```csharp
public class OrdersControllerIntegrationTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;
    private readonly WebApplicationFactory<Program> _factory;
    
    public OrdersControllerIntegrationTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory;
        _client = factory.CreateClient();
    }
    
    [Fact]
    public async Task CreateOrder_ValidRequest_ReturnsCreated()
    {
        // Arrange
        var request = new CreateOrderRequest
        {
            CustomerId = Guid.NewGuid(),
            Items = new List<OrderItemRequest>
            {
                new() { ProductId = Guid.NewGuid(), Quantity = 2 }
            }
        };
        
        var content = new StringContent(
            JsonSerializer.Serialize(request),
            Encoding.UTF8,
            "application/json"
        );
        
        // Act
        var response = await _client.PostAsync("/api/orders", content);
        
        // Assert
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        
        var responseContent = await response.Content.ReadAsStringAsync();
        var result = JsonSerializer.Deserialize<OrderResponse>(responseContent);
        
        Assert.NotNull(result);
        Assert.NotEqual(Guid.Empty, result.OrderId);
    }
    
    [Fact]
    public async Task GetOrder_ExistingOrder_ReturnsOrder()
    {
        // Arrange
        var orderId = await CreateTestOrderAsync();
        
        // Act
        var response = await _client.GetAsync($"/api/orders/{orderId}");
        
        // Assert
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        
        var content = await response.Content.ReadAsStringAsync();
        var order = JsonSerializer.Deserialize<OrderResponse>(content);
        
        Assert.NotNull(order);
        Assert.Equal(orderId, order.OrderId);
    }
    
    private async Task<Guid> CreateTestOrderAsync()
    {
        // Helper method - test uchun order yaratish
        var request = new CreateOrderRequest { /* ... */ };
        var response = await _client.PostAsync("/api/orders", /* ... */);
        var result = await response.Content.ReadAsStringAsync();
        return JsonSerializer.Deserialize<OrderResponse>(result).OrderId;
    }
}
```

---

## 4. Test-Driven Development (TDD)

**Jarayon:**

```
1. RED ───→ 2. GREEN ───→ 3. REFACTOR ───┐
   ↑                                      │
   └──────────────────────────────────────┘
```

1. **RED** - Test yozing (fail bo'ladi)
2. **GREEN** - Minimal kod yozing (test pass bo'lishi uchun)
3. **REFACTOR** - Kodni yaxshilang

### TDD Misol

```csharp
// 1. RED - Test yozamiz
[Fact]
public void CalculateDiscount_RegularCustomer_Returns5Percent()
{
    // Arrange
    var calculator = new DiscountCalculator();
    var customer = new Customer(CustomerType.Regular);
    decimal amount = 100m;
    
    // Act
    decimal discount = calculator.Calculate(customer, amount);
    
    // Assert
    Assert.Equal(5m, discount);
}

// 2. GREEN - Minimal kod
public class DiscountCalculator
{
    public decimal Calculate(Customer customer, decimal amount)
    {
        return 5m; // Hard-coded - test pass bo'ladi
    }
}

// 3. Yana test qo'shamiz
[Theory]
[InlineData(CustomerType.Regular, 100, 5)]
[InlineData(CustomerType.Premium, 100, 10)]
[InlineData(CustomerType.VIP, 100, 20)]
public void CalculateDiscount_DifferentCustomerTypes_ReturnsCorrectDiscount(
    CustomerType type, decimal amount, decimal expected)
{
    // Arrange
    var calculator = new DiscountCalculator();
    var customer = new Customer(type);
    
    // Act
    decimal discount = calculator.Calculate(customer, amount);
    
    // Assert
    Assert.Equal(expected, discount);
}

// 4. GREEN - To'g'ri implementation
public class DiscountCalculator
{
    public decimal Calculate(Customer customer, decimal amount)
    {
        var percentage = customer.Type switch
        {
            CustomerType.Regular => 0.05m,
            CustomerType.Premium => 0.10m,
            CustomerType.VIP => 0.20m,
            _ => 0m
        };
        
        return amount * percentage;
    }
}

// 5. REFACTOR - Strategy pattern bilan
public class DiscountCalculator
{
    private readonly Dictionary<CustomerType, IDiscountStrategy> _strategies;
    
    public DiscountCalculator()
    {
        _strategies = new Dictionary<CustomerType, IDiscountStrategy>
        {
            { CustomerType.Regular, new RegularCustomerDiscount() },
            { CustomerType.Premium, new PremiumCustomerDiscount() },
            { CustomerType.VIP, new VIPCustomerDiscount() }
        };
    }
    
    public decimal Calculate(Customer customer, decimal amount)
    {
        var strategy = _strategies[customer.Type];
        return strategy.Calculate(amount);
    }
}
```

---

## 5. Test Coverage

**Qancha kod test qilingan?**

```bash
# .NET da coverage o'lchash
dotnet test --collect:"XPlat Code Coverage"

# Report generatsiya
reportgenerator -reports:**/coverage.cobertura.xml -targetdir:coverage-report
```

**Coverage Target:**
- 80%+ - Yaxshi
- 90%+ - Juda yaxshi
- 100% - Keraksiz (testing overhead)

**Muhim:** Coverage 100% bo'lsa ham bug bo'lishi mumkin!

---

## 6. Test Doubles

### Dummy
```csharp
// Faqat parameter to'ldirish uchun
public void TestMethod()
{
    var dummy = new DummyEmailService(); // Ishlatilmaydi
    var service = new UserService(dummy);
}
```

### Stub
```csharp
// Qaytarish qiymati kerak
public class StubProductRepository : IProductRepository
{
    public Task<Product> GetByIdAsync(ProductId id)
    {
        return Task.FromResult(new Product(id, "Test Product", Money.Zero()));
    }
}
```

### Spy
```csharp
// Method chaqirilganligini kuzatish
public class SpyEmailService : IEmailService
{
    public int CallCount { get; private set; }
    public List<string> SentEmails { get; } = new();
    
    public Task SendAsync(string to, string message)
    {
        CallCount++;
        SentEmails.Add(to);
        return Task.CompletedTask;
    }
}
```

### Mock
```csharp
// Verify behavior
var mock = new Mock<IEmailService>();
mock.Setup(s => s.SendAsync(It.IsAny<string>(), It.IsAny<string>()));

// Use
await service.RegisterUserAsync(request);

// Verify
mock.Verify(s => s.SendAsync("user@example.com", It.IsAny<string>()), Times.Once);
```

---

## 7. Testing Best Practices

### ✅ Yaxshi Amaliyotlar

```csharp
// 1. Aniq test nomi
[Fact]
public void Withdraw_InsufficientBalance_ThrowsException() // ✅ Aniq
// vs
public void Test1() // ❌ Noaniq

// 2. Arrange-Act-Assert pattern
[Fact]
public void TestMethod()
{
    // Arrange - setup
    var sut = new SystemUnderTest();
    
    // Act - action
    var result = sut.DoSomething();
    
    // Assert - verify
    Assert.True(result);
}

// 3. Bir test - bir assertion (ideal)
[Fact]
public void Order_WhenConfirmed_StatusIsConfirmed()
{
    // Arrange
    var order = CreateValidOrder();
    
    // Act
    order.Confirm();
    
    // Assert
    Assert.Equal(OrderStatus.Confirmed, order.Status); // Faqat bittа
}

// 4. Test data builder pattern
public class OrderBuilder
{
    private OrderId _id = OrderId.New();
    private CustomerId _customerId = CustomerId.New();
    private List<OrderLine> _lines = new();
    
    public OrderBuilder WithId(OrderId id)
    {
        _id = id;
        return this;
    }
    
    public OrderBuilder WithCustomer(CustomerId customerId)
    {
        _customerId = customerId;
        return this;
    }
    
    public OrderBuilder WithLine(Product product, int quantity)
    {
        _lines.Add(new OrderLine(product, quantity));
        return this;
    }
    
    public Order Build()
    {
        var order = new Order(_id, _customerId);
        foreach (var line in _lines)
        {
            order.AddItem(line.Product, line.Quantity);
        }
        return order;
    }
}

// Ishlatish
var order = new OrderBuilder()
    .WithCustomer(customerId)
    .WithLine(product1, 2)
    .WithLine(product2, 1)
    .Build();
```

### ❌ Yomon Amaliyotlar

```csharp
// 1. Test'lar bir-biriga bog'liq
private static Order _sharedOrder; // ❌ Shared state

[Fact]
public void Test1()
{
    _sharedOrder = new Order();
}

[Fact]
public void Test2()
{
    _sharedOrder.Confirm(); // Test1 ga bog'liq!
}

// 2. External resource'larga bog'liq
[Fact]
public void TestWithRealDatabase() // ❌ Sekin, mo'rt
{
    using var connection = new SqlConnection("real-db-connection");
    // ...
}

// 3. Random data
[Fact]
public void TestWithRandomData() // ❌ Har safar turli natija
{
    var random = new Random();
    var amount = random.Next(1, 100);
    // Test har safar turli natija berishi mumkin!
}

// 4. Test qilishning o'zi test kerak bo'lgan murakkab logic
[Fact]
public void ComplexTest() // ❌ Test oddiy bo'lishi kerak
{
    // 100 qator setup kod
    // if-else, loop'lar
    // Test'ning o'zi bug bo'lishi mumkin!
}
```

---

## 8. Performance Testing

```csharp
[Fact]
public void CalculateDiscount_Performance_CompletesWithin100ms()
{
    // Arrange
    var calculator = new DiscountCalculator();
    var stopwatch = Stopwatch.StartNew();
    
    // Act
    for (int i = 0; i < 1000; i++)
    {
        calculator.Calculate(customer, 100m);
    }
    
    stopwatch.Stop();
    
    // Assert
    Assert.True(stopwatch.ElapsedMilliseconds < 100, 
        $"Expected < 100ms, but took {stopwatch.ElapsedMilliseconds}ms");
}
```

### BenchmarkDotNet

```csharp
[MemoryDiagnoser]
public class DiscountBenchmarks
{
    private DiscountCalculator _calculator;
    private Customer _customer;
    
    [GlobalSetup]
    public void Setup()
    {
        _calculator = new DiscountCalculator();
        _customer = new Customer(CustomerType.Premium);
    }
    
    [Benchmark]
    public decimal CalculateDiscount()
    {
        return _calculator.Calculate(_customer, 100m);
    }
}
```

---

## 9. Mutation Testing

**Maqsad:** Test'larning sifatini tekshirish

```bash
# Stryker.NET - Mutation testing tool
dotnet tool install -g dotnet-stryker
dotnet stryker
```

**Qanday ishlaydi:**
1. Kod'ni o'zgartiradi (mutation)
2. Test'larni ishga tushiradi
3. Agar test fail bo'lsa - yaxshi (mutation killed)
4. Agar test pass bo'lsa - yomon (mutation survived)

---

## 10. Testing Anti-Patterns

### Ice Cream Cone (Teskari pyramid)
```
╲                  ╱  ← Juda ko'p E2E test (sekin, mo'rt)
 ╲                ╱   
  ╲              ╱    ← Kam integration test
   ╲            ╱     
    ╲          ╱      ← Juda kam unit test
     ╲________╱       
```

### Testing Implementation Details
```csharp
// ❌ YOMON - Private method test qilish
[Fact]
public void TestPrivateMethod()
{
    var obj = new MyClass();
    var method = typeof(MyClass).GetMethod("PrivateMethod", 
        BindingFlags.NonPublic | BindingFlags.Instance);
    var result = method.Invoke(obj, null);
    Assert.NotNull(result);
}

// ✅ YAXSHI - Public API test qilish
[Fact]
public void TestPublicBehavior()
{
    var obj = new MyClass();
    var result = obj.PublicMethod(); // Bu private method'ni chaqiradi
    Assert.NotNull(result);
}
```

---

## Keyingi Qadamlar

Testing'ni o'rgandingiz! Endi:

1. **Performance Optimization** - Tez ishlash
2. **Security Best Practices** - Xavfsizlik
3. **Database Design** - Ma'lumotlar bazasi

Keyingi bo'lim: [Database Design](./06-database-design.md)
