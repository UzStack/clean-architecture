# Domain-Driven Design (DDD) - To'liq Qo'llanma

Domain-Driven Design - bu murakkab biznes logikasini dasturda to'g'ri aks ettirishga qaratilgan yondashuv.

---

## DDD Nima?

DDD - bu Eric Evans tomonidan taklif qilingan yondashuv bo'lib, asosiy g'oyasi:

**"Dastur biznes domain'ini to'liq aks ettirishi kerak"**

### Asosiy Prinsiplar

1. **Ubiquitous Language** - Umumiy til
2. **Bounded Context** - Chegaralangan kontekst
3. **Strategic Design** - Strategik dizayn
4. **Tactical Design** - Taktik dizayn

---

## Ubiquitous Language (Umumiy Til)

**Muammo:** Dasturchilar va biznes mutaxassislari turli tillarni ishlatadi.

```
Biznes: "Buyurtmani tasdiqlash kerak"
Dasturchi: "Order status'ni 'confirmed' ga o'zgartirish kerak"
```

**Yechim:** Bir xil atamalarni ishlating!

### ❌ Noto'g'ri

```csharp
// Dasturchilar tili
public class OrderRecord
{
    public void MarkAsProcessed() { } // Biznes buni tushunmaydi
    public void SetFlag(int flag) { }
}
```

### ✅ To'g'ri

```csharp
// Biznes tili
public class Order
{
    public void Confirm() { } // Biznes tushunadi
    public void Ship() { }
    public void Cancel() { }
    public void Complete() { }
}
```

**Qoida:** Kod biznes bilan gaplashgandek yozilishi kerak!

---

## Bounded Context (Chegaralangan Kontekst)

**Muammo:** Bir xil atama turli joylarda turli ma'noni bildiradi.

**Misol:** "Customer" so'zi

- **Sales Context:** Customer - mahsulot sotib oluvchi
- **Support Context:** Customer - yordam so'rovchi
- **Shipping Context:** Customer - yetkazib berish manzili

### Yechim: Har bir kontekstda alohida model

```csharp
// Sales Context
namespace Sales
{
    public class Customer
    {
        public CustomerId Id { get; private set; }
        public string Name { get; private set; }
        public CreditLimit CreditLimit { get; private set; }
        public List<Order> Orders { get; private set; }
        
        public bool CanPlaceOrder(decimal amount)
        {
            return CreditLimit.IsAvailable(amount);
        }
    }
}

// Support Context
namespace Support
{
    public class Customer
    {
        public CustomerId Id { get; private set; }
        public string Name { get; private set; }
        public List<Ticket> Tickets { get; private set; }
        public SupportTier Tier { get; private set; }
        
        public TimeSpan GetResponseTime()
        {
            return Tier.ResponseTime;
        }
    }
}

// Shipping Context
namespace Shipping
{
    public class Customer
    {
        public CustomerId Id { get; private set; }
        public Address DeliveryAddress { get; private set; }
        public List<Shipment> Shipments { get; private set; }
    }
}
```

**Har bir context o'z modeliga ega!**

---

## Building Blocks (Qurilish Bloklari)

### 1. Entity (Identifikatsiyaga ega obyekt)

**Xususiyati:** ID bilan farqlanadi, atributlari o'zgarishi mumkin

```csharp
public class Order : Entity
{
    public OrderId Id { get; private set; }
    public CustomerId CustomerId { get; private set; }
    public OrderStatus Status { get; private set; }
    public DateTime CreatedAt { get; private set; }
    private List<OrderLine> _lines = new();
    
    public Order(OrderId id, CustomerId customerId)
    {
        Id = id;
        CustomerId = customerId;
        Status = OrderStatus.Draft;
        CreatedAt = DateTime.UtcNow;
    }
    
    public void AddLine(Product product, int quantity)
    {
        var line = new OrderLine(product.Id, product.Price, quantity);
        _lines.Add(line);
    }
    
    public void Confirm()
    {
        if (Status != OrderStatus.Draft)
            throw new InvalidOperationException("Only draft orders can be confirmed");
            
        if (!_lines.Any())
            throw new InvalidOperationException("Cannot confirm empty order");
            
        Status = OrderStatus.Confirmed;
    }
}

// Identity
public class OrderId : ValueObject
{
    public Guid Value { get; }
    
    public OrderId(Guid value)
    {
        if (value == Guid.Empty)
            throw new ArgumentException("Order ID cannot be empty");
            
        Value = value;
    }
    
    protected override IEnumerable<object> GetEqualityComponents()
    {
        yield return Value;
    }
}
```

**Entity'ning belgilari:**
- ✅ Unique ID'ga ega
- ✅ Lifecycle'i bor (yaratiladi, o'zgaradi, o'chiriladi)
- ✅ ID bir xil bo'lsa, entity bir xil

---

### 2. Value Object (Qiymat Obyekti)

**Xususiyati:** ID yo'q, atributlari bilan farqlanadi, immutable

```csharp
public class Money : ValueObject
{
    public decimal Amount { get; }
    public string Currency { get; }
    
    public Money(decimal amount, string currency)
    {
        if (amount < 0)
            throw new ArgumentException("Amount cannot be negative");
            
        if (string.IsNullOrEmpty(currency))
            throw new ArgumentException("Currency is required");
            
        Amount = amount;
        Currency = currency;
    }
    
    public Money Add(Money other)
    {
        if (Currency != other.Currency)
            throw new InvalidOperationException("Cannot add different currencies");
            
        return new Money(Amount + other.Amount, Currency);
    }
    
    public Money Multiply(decimal factor)
    {
        return new Money(Amount * factor, Currency);
    }
    
    protected override IEnumerable<object> GetEqualityComponents()
    {
        yield return Amount;
        yield return Currency;
    }
}

public class Address : ValueObject
{
    public string Street { get; }
    public string City { get; }
    public string PostalCode { get; }
    public string Country { get; }
    
    public Address(string street, string city, string postalCode, string country)
    {
        Street = street ?? throw new ArgumentNullException(nameof(street));
        City = city ?? throw new ArgumentNullException(nameof(city));
        PostalCode = postalCode ?? throw new ArgumentNullException(nameof(postalCode));
        Country = country ?? throw new ArgumentNullException(nameof(country));
    }
    
    protected override IEnumerable<object> GetEqualityComponents()
    {
        yield return Street;
        yield return City;
        yield return PostalCode;
        yield return Country;
    }
}

// Base class
public abstract class ValueObject
{
    protected abstract IEnumerable<object> GetEqualityComponents();
    
    public override bool Equals(object obj)
    {
        if (obj == null || obj.GetType() != GetType())
            return false;
            
        var other = (ValueObject)obj;
        
        return GetEqualityComponents().SequenceEqual(other.GetEqualityComponents());
    }
    
    public override int GetHashCode()
    {
        return GetEqualityComponents()
            .Select(x => x?.GetHashCode() ?? 0)
            .Aggregate((x, y) => x ^ y);
    }
}
```

**Value Object'ning belgilari:**
- ✅ ID yo'q
- ✅ Immutable (o'zgarmas)
- ✅ Atributlari bilan tenglanadi
- ✅ O'rnini bosishi mumkin

**Qachon ishlatish:**
- Money, Address, Email, PhoneNumber
- Date Range, Coordinates
- Har qanday measurement

---

### 3. Aggregate (Agregat)

**Maqsad:** Bir necha entity va value object'larni bitta consistency boundary'da birlashtirish

**Qoidalar:**
1. Aggregate Root orqali kirish
2. Tashqaridan faqat Root'ga murojaat
3. Root barcha consistency'ni kafolatlaydi

```csharp
// Aggregate Root
public class Order : AggregateRoot<OrderId>
{
    // Aggregate ichidagi entity'lar
    private List<OrderLine> _lines = new();
    
    // Aggregate ichidagi value object'lar
    public Money TotalAmount { get; private set; }
    public Address ShippingAddress { get; private set; }
    
    // State
    public OrderStatus Status { get; private set; }
    
    // Constructor - faqat valid state
    public Order(OrderId id, CustomerId customerId, Address shippingAddress)
    {
        Id = id;
        CustomerId = customerId;
        ShippingAddress = shippingAddress ?? throw new ArgumentNullException();
        Status = OrderStatus.Draft;
        TotalAmount = Money.Zero("USD");
    }
    
    // Business logic - consistency kafolatlanadi
    public void AddLine(Product product, int quantity)
    {
        if (Status != OrderStatus.Draft)
            throw new DomainException("Cannot add items to non-draft order");
            
        var line = new OrderLine(
            LineId.New(),
            product.Id,
            product.Name,
            product.Price,
            quantity
        );
        
        _lines.Add(line);
        RecalculateTotal(); // Consistency
    }
    
    public void RemoveLine(LineId lineId)
    {
        if (Status != OrderStatus.Draft)
            throw new DomainException("Cannot remove items from non-draft order");
            
        var line = _lines.FirstOrDefault(l => l.Id == lineId);
        if (line != null)
        {
            _lines.Remove(line);
            RecalculateTotal(); // Consistency
        }
    }
    
    public void ChangeShippingAddress(Address newAddress)
    {
        if (Status == OrderStatus.Shipped || Status == OrderStatus.Delivered)
            throw new DomainException("Cannot change address for shipped orders");
            
        ShippingAddress = newAddress;
    }
    
    public void Confirm()
    {
        if (Status != OrderStatus.Draft)
            throw new DomainException("Only draft orders can be confirmed");
            
        if (!_lines.Any())
            throw new DomainException("Cannot confirm empty order");
            
        Status = OrderStatus.Confirmed;
        
        // Domain event
        AddDomainEvent(new OrderConfirmedEvent(Id, CustomerId, TotalAmount));
    }
    
    private void RecalculateTotal()
    {
        var total = _lines
            .Select(l => l.Price.Multiply(l.Quantity))
            .Aggregate(Money.Zero("USD"), (acc, price) => acc.Add(price));
            
        TotalAmount = total;
    }
}

// Aggregate ichidagi entity (tashqaridan ko'rinmaydi)
internal class OrderLine : Entity<LineId>
{
    public ProductId ProductId { get; private set; }
    public string ProductName { get; private set; }
    public Money Price { get; private set; }
    public int Quantity { get; private set; }
    
    public OrderLine(LineId id, ProductId productId, string productName, Money price, int quantity)
    {
        Id = id;
        ProductId = productId;
        ProductName = productName;
        Price = price;
        Quantity = quantity;
    }
}
```

**Aggregate qoidalari:**
- ✅ Kichik aggregate'lar yaxshi (2-3 entity)
- ✅ Reference by ID (boshqa aggregate'larga ID orqali)
- ✅ Bir transaction = bir aggregate
- ✅ Eventual consistency aggregate'lar o'rtasida

---

### 4. Domain Service

**Qachon kerak?** Biznes logika bir entity'ga tegishli bo'lmaganda

```csharp
// ❌ Entity'ga tegishli emas
public class Order
{
    public bool CanShipTo(Address address, IShippingRules rules)
    {
        // Bu Order'ning vazifasi emas!
    }
}

// ✅ Domain Service
public interface IOrderShippingService
{
    bool CanShipTo(Order order, Address address);
    Money CalculateShippingCost(Order order, Address address);
}

public class OrderShippingService : IOrderShippingService
{
    private readonly IShippingRuleRepository _ruleRepository;
    
    public OrderShippingService(IShippingRuleRepository ruleRepository)
    {
        _ruleRepository = ruleRepository;
    }
    
    public bool CanShipTo(Order order, Address address)
    {
        var rules = _ruleRepository.GetRulesForCountry(address.Country);
        
        // Murakkab biznes logika
        foreach (var rule in rules)
        {
            if (!rule.AllowsShipping(order, address))
                return false;
        }
        
        return true;
    }
    
    public Money CalculateShippingCost(Order order, Address address)
    {
        // Bir necha entity va external service'lar bilan ishlash
        var baseRate = GetBaseRate(address.Country);
        var weight = CalculateTotalWeight(order);
        var distance = CalculateDistance(order.OriginAddress, address);
        
        return baseRate.Multiply(weight).Multiply(distance);
    }
}
```

**Domain Service vs Application Service:**

| Domain Service | Application Service |
|----------------|---------------------|
| Biznes logika | Orchestration |
| Domain model bilan ishlaydi | Use case implement qiladi |
| Stateless | Stateless |
| Domain layer | Application layer |

---

### 5. Repository

**Maqsad:** Aggregate'larni persistence'dan olish va saqlash

```csharp
// Repository interface - Domain layer'da
public interface IOrderRepository
{
    Task<Order> GetByIdAsync(OrderId id);
    Task<List<Order>> GetByCustomerAsync(CustomerId customerId);
    Task AddAsync(Order order);
    Task UpdateAsync(Order order);
    Task DeleteAsync(OrderId id);
}

// Repository implementation - Infrastructure layer'da
public class OrderRepository : IOrderRepository
{
    private readonly ApplicationDbContext _context;
    
    public OrderRepository(ApplicationDbContext context)
    {
        _context = context;
    }
    
    public async Task<Order> GetByIdAsync(OrderId id)
    {
        var orderDb = await _context.Orders
            .Include(o => o.Lines)
            .FirstOrDefaultAsync(o => o.Id == id.Value);
            
        if (orderDb == null)
            return null;
            
        return MapToDomain(orderDb);
    }
    
    public async Task AddAsync(Order order)
    {
        var orderDb = MapToDatabase(order);
        await _context.Orders.AddAsync(orderDb);
    }
    
    private Order MapToDomain(OrderDb orderDb)
    {
        // Database model -> Domain aggregate
        var order = new Order(
            new OrderId(orderDb.Id),
            new CustomerId(orderDb.CustomerId),
            new Address(orderDb.Street, orderDb.City, orderDb.PostalCode, orderDb.Country)
        );
        
        foreach (var lineDb in orderDb.Lines)
        {
            order.AddLine(
                new Product(/* ... */),
                lineDb.Quantity
            );
        }
        
        return order;
    }
}
```

**Repository qoidalari:**
- ✅ Faqat Aggregate Root uchun
- ✅ Collection kabi ishlaydi
- ✅ Domain layer'da interface
- ✅ Infrastructure layer'da implementation

---

### 6. Domain Events

**Maqsad:** Muhim biznes voqealarini e'lon qilish

```csharp
// Domain Event
public class OrderConfirmedEvent : DomainEvent
{
    public OrderId OrderId { get; }
    public CustomerId CustomerId { get; }
    public Money TotalAmount { get; }
    public DateTime ConfirmedAt { get; }
    
    public OrderConfirmedEvent(OrderId orderId, CustomerId customerId, Money totalAmount)
    {
        OrderId = orderId;
        CustomerId = customerId;
        TotalAmount = totalAmount;
        ConfirmedAt = DateTime.UtcNow;
    }
}

// Aggregate'da event qo'shish
public class Order : AggregateRoot<OrderId>
{
    public void Confirm()
    {
        // Business logic
        Status = OrderStatus.Confirmed;
        
        // Event qo'shish
        AddDomainEvent(new OrderConfirmedEvent(Id, CustomerId, TotalAmount));
    }
}

// Base class
public abstract class AggregateRoot<TId> : Entity<TId>
{
    private List<DomainEvent> _domainEvents = new();
    public IReadOnlyCollection<DomainEvent> DomainEvents => _domainEvents.AsReadOnly();
    
    protected void AddDomainEvent(DomainEvent eventItem)
    {
        _domainEvents.Add(eventItem);
    }
    
    public void ClearDomainEvents()
    {
        _domainEvents.Clear();
    }
}

// Event handler
public class OrderConfirmedEventHandler : IDomainEventHandler<OrderConfirmedEvent>
{
    private readonly IEmailService _emailService;
    private readonly IInventoryService _inventoryService;
    
    public async Task Handle(OrderConfirmedEvent @event)
    {
        // Email yuborish
        await _emailService.SendOrderConfirmationAsync(@event.OrderId);
        
        // Inventory'ni reserve qilish
        await _inventoryService.ReserveStockAsync(@event.OrderId);
    }
}
```

**Domain Events afzalliklari:**
- ✅ Loose coupling
- ✅ Biznes voqealarini aniq ko'rsatish
- ✅ Audit trail
- ✅ Event Sourcing imkoniyati

---

## Specifications Pattern

**Maqsad:** Biznes qoidalarini qayta ishlatish va kombinatsiya qilish

```csharp
// Base specification
public interface ISpecification<T>
{
    bool IsSatisfiedBy(T entity);
}

public abstract class Specification<T> : ISpecification<T>
{
    public abstract bool IsSatisfiedBy(T entity);
    
    public Specification<T> And(Specification<T> other)
    {
        return new AndSpecification<T>(this, other);
    }
    
    public Specification<T> Or(Specification<T> other)
    {
        return new OrSpecification<T>(this, other);
    }
    
    public Specification<T> Not()
    {
        return new NotSpecification<T>(this);
    }
}

// Concrete specifications
public class CustomerIsActiveSpecification : Specification<Customer>
{
    public override bool IsSatisfiedBy(Customer customer)
    {
        return customer.Status == CustomerStatus.Active;
    }
}

public class CustomerHasGoodCreditSpecification : Specification<Customer>
{
    public override bool IsSatisfiedBy(Customer customer)
    {
        return customer.CreditScore >= 700;
    }
}

public class CustomerCanPlaceOrderSpecification : Specification<Customer>
{
    private readonly decimal _orderAmount;
    
    public CustomerCanPlaceOrderSpecification(decimal orderAmount)
    {
        _orderAmount = orderAmount;
    }
    
    public override bool IsSatisfiedBy(Customer customer)
    {
        return customer.CreditLimit.AvailableAmount >= _orderAmount;
    }
}

// Kombinatsiya
var canPlaceOrder = new CustomerIsActiveSpecification()
    .And(new CustomerHasGoodCreditSpecification())
    .And(new CustomerCanPlaceOrderSpecification(1000));

if (canPlaceOrder.IsSatisfiedBy(customer))
{
    // Order qabul qilish mumkin
}
```

---

## DDD va Clean Architecture

DDD va Clean Architecture juda yaxshi birlashadi:

```
┌─────────────────────────────────────────────────┐
│                Infrastructure                   │
│  ┌──────────────────────────────────────────┐  │
│  │          Application Layer               │  │
│  │  ┌────────────────────────────────────┐  │  │
│  │  │       Domain Layer (DDD)           │  │  │
│  │  │  - Entities                        │  │  │
│  │  │  - Value Objects                   │  │  │
│  │  │  - Aggregates                      │  │  │
│  │  │  - Domain Services                 │  │  │
│  │  │  - Domain Events                   │  │  │
│  │  │  - Specifications                  │  │  │
│  │  └────────────────────────────────────┘  │  │
│  │  - Use Cases                             │  │
│  │  - Application Services                  │  │
│  └──────────────────────────────────────────┘  │
│  - Repositories (Implementation)                │
│  - External Services                            │
└─────────────────────────────────────────────────┘
```

---

## Amaliy Misol: E-commerce Order System

### Domain Model

```csharp
// 1. Value Objects
public class Money : ValueObject { /* ... */ }
public class ProductId : ValueObject { /* ... */ }
public class CustomerId : ValueObject { /* ... */ }

// 2. Entities
public class Product : Entity<ProductId>
{
    public string Name { get; private set; }
    public Money Price { get; private set; }
    public int StockQuantity { get; private set; }
    
    public void DecreaseStock(int quantity)
    {
        if (quantity > StockQuantity)
            throw new DomainException("Insufficient stock");
            
        StockQuantity -= quantity;
        AddDomainEvent(new StockDecreasedEvent(Id, quantity));
    }
}

// 3. Aggregate Root
public class Order : AggregateRoot<OrderId>
{
    private List<OrderLine> _lines = new();
    public IReadOnlyList<OrderLine> Lines => _lines;
    
    public CustomerId CustomerId { get; private set; }
    public Money TotalAmount { get; private set; }
    public OrderStatus Status { get; private set; }
    
    public void AddLine(Product product, int quantity)
    {
        if (Status != OrderStatus.Draft)
            throw new DomainException("Cannot modify confirmed order");
            
        var line = new OrderLine(product, quantity);
        _lines.Add(line);
        RecalculateTotal();
    }
    
    public void Confirm()
    {
        var spec = new OrderCanBeConfirmedSpecification();
        if (!spec.IsSatisfiedBy(this))
            throw new DomainException("Order cannot be confirmed");
            
        Status = OrderStatus.Confirmed;
        AddDomainEvent(new OrderConfirmedEvent(Id, CustomerId));
    }
    
    private void RecalculateTotal()
    {
        TotalAmount = _lines
            .Select(l => l.TotalPrice)
            .Aggregate(Money.Zero("USD"), (a, b) => a.Add(b));
    }
}

// 4. Specification
public class OrderCanBeConfirmedSpecification : Specification<Order>
{
    public override bool IsSatisfiedBy(Order order)
    {
        return order.Status == OrderStatus.Draft
            && order.Lines.Any()
            && order.TotalAmount.Amount > 0;
    }
}

// 5. Domain Service
public class OrderPricingService
{
    public Money CalculateTotalWithDiscount(Order order, Customer customer)
    {
        var total = order.TotalAmount;
        
        if (customer.IsVip)
            total = total.Multiply(0.9m); // 10% discount
            
        return total;
    }
}

// 6. Repository
public interface IOrderRepository
{
    Task<Order> GetByIdAsync(OrderId id);
    Task AddAsync(Order order);
    Task UpdateAsync(Order order);
}
```

---

## DDD Anti-Patterns

### ❌ Anemic Domain Model

```csharp
// YOMON - Faqat data, logic yo'q
public class Order
{
    public int Id { get; set; }
    public decimal Total { get; set; }
    public string Status { get; set; }
}

public class OrderService
{
    public void ConfirmOrder(Order order)
    {
        // Barcha logic service'da!
        if (order.Status == "Draft")
        {
            order.Status = "Confirmed";
            // ...
        }
    }
}
```

### ✅ Rich Domain Model

```csharp
// YAXSHI - Logic domain'da
public class Order
{
    public OrderStatus Status { get; private set; }
    
    public void Confirm()
    {
        if (Status != OrderStatus.Draft)
            throw new DomainException("...");
            
        Status = OrderStatus.Confirmed;
    }
}
```

---

## Keyingi Qadamlar

DDD'ni o'rgandingiz! Endi:

1. **CQRS** - Command Query Responsibility Segregation
2. **Event Sourcing** - Event'lar asosida state boshqarish
3. **Microservices** - DDD va microservices

Keyingi bo'lim: [Testing Strategiyalari](./05-testing-strategies.md)
