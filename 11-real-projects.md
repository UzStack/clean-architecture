# Real Projects - Amaliy Loyihalar

Nazariyadan amaliyotga! Real loyihalar orqali o'rganing.

---

## Project 1: E-Commerce Platform (To'liq)

### Tech Stack
- **Backend:** ASP.NET Core 7.0
- **Frontend:** React + TypeScript
- **Database:** PostgreSQL
- **Cache:** Redis
- **Message Queue:** RabbitMQ
- **Search:** Elasticsearch
- **Storage:** AWS S3
- **Deployment:** Docker + Kubernetes

### Architecture

```
┌─────────────────────────────────────────┐
│         API Gateway (YARP)              │
└────────────┬────────────────────────────┘
             │
    ┌────────┴────────┬──────────┬─────────┐
    │                 │          │         │
┌───▼───┐      ┌─────▼────┐  ┌──▼──┐  ┌──▼───┐
│Product│      │ Order    │  │User │  │Search│
│Service│      │ Service  │  │Svc  │  │ Svc  │
└───────┘      └──────────┘  └─────┘  └──────┘
    │               │           │         │
    ▼               ▼           ▼         ▼
┌─────────────────────────────────────────┐
│         PostgreSQL (Sharded)            │
└─────────────────────────────────────────┘
```

### Project Structure

```
ECommerce/
├── src/
│   ├── Services/
│   │   ├── Product/
│   │   │   ├── Product.API/
│   │   │   ├── Product.Application/
│   │   │   ├── Product.Domain/
│   │   │   ├── Product.Infrastructure/
│   │   │   └── Product.Tests/
│   │   ├── Order/
│   │   ├── User/
│   │   └── Search/
│   ├── ApiGateway/
│   ├── Common/
│   │   ├── Common.Domain/
│   │   ├── Common.Application/
│   │   └── Common.Infrastructure/
│   └── Web/
│       └── ecommerce-web/ (React)
├── docker-compose.yml
├── k8s/
└── README.md
```

### 1. Product Service

**Domain Layer:**

```csharp
// Product.Domain/Entities/Product.cs
public class Product : AggregateRoot
{
    public string Name { get; private set; }
    public string Description { get; private set; }
    public Money Price { get; private set; }
    public int StockQuantity { get; private set; }
    public ProductCategory Category { get; private set; }
    public List<ProductImage> Images { get; private set; } = new();
    public ProductStatus Status { get; private set; }
    
    private Product() { } // EF Constructor
    
    public static Product Create(
        string name,
        string description,
        Money price,
        int stockQuantity,
        ProductCategory category)
    {
        var product = new Product
        {
            Id = Guid.NewGuid(),
            Name = name,
            Description = description,
            Price = price,
            StockQuantity = stockQuantity,
            Category = category,
            Status = ProductStatus.Draft
        };
        
        product.AddDomainEvent(new ProductCreatedEvent(product));
        return product;
    }
    
    public void UpdateStock(int quantity)
    {
        if (quantity < 0)
            throw new DomainException("Stock quantity cannot be negative");
            
        StockQuantity = quantity;
        AddDomainEvent(new StockUpdatedEvent(Id, quantity));
    }
    
    public void Publish()
    {
        if (string.IsNullOrEmpty(Name))
            throw new DomainException("Product name is required");
            
        if (Price.Amount <= 0)
            throw new DomainException("Product price must be positive");
            
        Status = ProductStatus.Published;
        AddDomainEvent(new ProductPublishedEvent(Id));
    }
}

// Value Object
public class Money : ValueObject
{
    public decimal Amount { get; private set; }
    public string Currency { get; private set; }
    
    public Money(decimal amount, string currency)
    {
        if (amount < 0)
            throw new ArgumentException("Amount cannot be negative");
            
        Amount = amount;
        Currency = currency;
    }
    
    protected override IEnumerable<object> GetEqualityComponents()
    {
        yield return Amount;
        yield return Currency;
    }
    
    public static Money operator +(Money a, Money b)
    {
        if (a.Currency != b.Currency)
            throw new InvalidOperationException("Cannot add different currencies");
            
        return new Money(a.Amount + b.Amount, a.Currency);
    }
}
```

**Application Layer:**

```csharp
// Product.Application/Commands/CreateProductCommand.cs
public record CreateProductCommand(
    string Name,
    string Description,
    decimal Price,
    string Currency,
    int StockQuantity,
    Guid CategoryId
) : IRequest<Guid>;

public class CreateProductCommandHandler 
    : IRequestHandler<CreateProductCommand, Guid>
{
    private readonly IProductRepository _repository;
    private readonly IUnitOfWork _unitOfWork;
    private readonly ICategoryRepository _categoryRepository;
    
    public async Task<Guid> Handle(
        CreateProductCommand request,
        CancellationToken cancellationToken)
    {
        // Validate category exists
        var category = await _categoryRepository.GetByIdAsync(request.CategoryId);
        if (category == null)
            throw new NotFoundException("Category not found");
        
        // Create product
        var product = Product.Create(
            request.Name,
            request.Description,
            new Money(request.Price, request.Currency),
            request.StockQuantity,
            category
        );
        
        // Save
        await _repository.AddAsync(product);
        await _unitOfWork.SaveChangesAsync(cancellationToken);
        
        return product.Id;
    }
}

// Product.Application/Queries/GetProductQuery.cs
public record GetProductQuery(Guid Id) : IRequest<ProductDto>;

public class GetProductQueryHandler 
    : IRequestHandler<GetProductQuery, ProductDto>
{
    private readonly IProductRepository _repository;
    private readonly IMemoryCache _cache;
    
    public async Task<ProductDto> Handle(
        GetProductQuery request,
        CancellationToken cancellationToken)
    {
        var cacheKey = $"product:{request.Id}";
        
        // Try cache
        if (_cache.TryGetValue(cacheKey, out ProductDto cached))
            return cached;
        
        // Get from DB
        var product = await _repository.GetByIdAsync(request.Id);
        if (product == null)
            throw new NotFoundException("Product not found");
        
        var dto = ProductDto.FromEntity(product);
        
        // Set cache
        _cache.Set(cacheKey, dto, TimeSpan.FromMinutes(10));
        
        return dto;
    }
}
```

**API Layer:**

```csharp
// Product.API/Controllers/ProductsController.cs
[ApiController]
[Route("api/[controller]")]
public class ProductsController : ControllerBase
{
    private readonly IMediator _mediator;
    
    [HttpPost]
    [Authorize(Roles = "Admin")]
    [ProducesResponseType(typeof(Guid), StatusCodes.Status201Created)]
    public async Task<IActionResult> CreateProduct(
        [FromBody] CreateProductRequest request)
    {
        var command = new CreateProductCommand(
            request.Name,
            request.Description,
            request.Price,
            request.Currency,
            request.StockQuantity,
            request.CategoryId
        );
        
        var productId = await _mediator.Send(command);
        
        return CreatedAtAction(
            nameof(GetProduct),
            new { id = productId },
            productId
        );
    }
    
    [HttpGet("{id}")]
    [ResponseCache(Duration = 60)]
    [ProducesResponseType(typeof(ProductDto), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetProduct(Guid id)
    {
        var query = new GetProductQuery(id);
        var product = await _mediator.Send(query);
        return Ok(product);
    }
    
    [HttpGet]
    [ProducesResponseType(typeof(PagedResult<ProductDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetProducts(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20,
        [FromQuery] string? category = null,
        [FromQuery] decimal? minPrice = null,
        [FromQuery] decimal? maxPrice = null)
    {
        var query = new GetProductsQuery(page, pageSize, category, minPrice, maxPrice);
        var products = await _mediator.Send(query);
        return Ok(products);
    }
}
```

### 2. Order Service

**Domain Layer:**

```csharp
// Order.Domain/Entities/Order.cs
public class Order : AggregateRoot
{
    public Guid CustomerId { get; private set; }
    public List<OrderItem> Items { get; private set; } = new();
    public Money TotalAmount { get; private set; }
    public OrderStatus Status { get; private set; }
    public ShippingAddress ShippingAddress { get; private set; }
    
    public static Order Create(Guid customerId, ShippingAddress address)
    {
        var order = new Order
        {
            Id = Guid.NewGuid(),
            CustomerId = customerId,
            ShippingAddress = address,
            Status = OrderStatus.Pending,
            TotalAmount = new Money(0, "USD")
        };
        
        order.AddDomainEvent(new OrderCreatedEvent(order.Id, customerId));
        return order;
    }
    
    public void AddItem(Guid productId, string productName, Money price, int quantity)
    {
        if (Status != OrderStatus.Pending)
            throw new DomainException("Cannot modify confirmed order");
        
        var existingItem = Items.FirstOrDefault(i => i.ProductId == productId);
        
        if (existingItem != null)
        {
            existingItem.IncreaseQuantity(quantity);
        }
        else
        {
            var item = OrderItem.Create(productId, productName, price, quantity);
            Items.Add(item);
        }
        
        RecalculateTotal();
    }
    
    public void Confirm()
    {
        if (Items.Count == 0)
            throw new DomainException("Cannot confirm empty order");
        
        Status = OrderStatus.Confirmed;
        AddDomainEvent(new OrderConfirmedEvent(Id, CustomerId, TotalAmount));
    }
    
    private void RecalculateTotal()
    {
        TotalAmount = Items
            .Select(i => i.TotalPrice)
            .Aggregate((a, b) => a + b);
    }
}

public class OrderItem : Entity
{
    public Guid ProductId { get; private set; }
    public string ProductName { get; private set; }
    public Money UnitPrice { get; private set; }
    public int Quantity { get; private set; }
    public Money TotalPrice { get; private set; }
    
    public static OrderItem Create(
        Guid productId,
        string productName,
        Money unitPrice,
        int quantity)
    {
        return new OrderItem
        {
            Id = Guid.NewGuid(),
            ProductId = productId,
            ProductName = productName,
            UnitPrice = unitPrice,
            Quantity = quantity,
            TotalPrice = new Money(unitPrice.Amount * quantity, unitPrice.Currency)
        };
    }
    
    public void IncreaseQuantity(int amount)
    {
        Quantity += amount;
        TotalPrice = new Money(UnitPrice.Amount * Quantity, UnitPrice.Currency);
    }
}
```

**Application Layer (Saga Pattern):**

```csharp
// Order.Application/Sagas/OrderProcessingSaga.cs
public class OrderProcessingSaga
{
    private readonly IMediator _mediator;
    private readonly IMessageBus _messageBus;
    
    public async Task ProcessOrderAsync(Guid orderId)
    {
        try
        {
            // Step 1: Reserve inventory
            await _messageBus.PublishAsync(new ReserveInventoryCommand(orderId));
            
            // Step 2: Process payment
            await _messageBus.PublishAsync(new ProcessPaymentCommand(orderId));
            
            // Step 3: Ship order
            await _messageBus.PublishAsync(new ShipOrderCommand(orderId));
            
            // Step 4: Complete order
            await _mediator.Send(new CompleteOrderCommand(orderId));
        }
        catch (Exception ex)
        {
            // Compensating transactions
            await CompensateAsync(orderId);
            throw;
        }
    }
    
    private async Task CompensateAsync(Guid orderId)
    {
        await _messageBus.PublishAsync(new ReleaseInventoryCommand(orderId));
        await _messageBus.PublishAsync(new RefundPaymentCommand(orderId));
        await _mediator.Send(new CancelOrderCommand(orderId));
    }
}
```

### 3. Integration Events

```csharp
// Common.Application/Events/OrderConfirmedEvent.cs
public record OrderConfirmedEvent(
    Guid OrderId,
    Guid CustomerId,
    Money TotalAmount
) : IIntegrationEvent;

// Order.Application/EventHandlers/OrderConfirmedEventHandler.cs
public class OrderConfirmedEventHandler 
    : INotificationHandler<OrderConfirmedEvent>
{
    private readonly IMessageBus _messageBus;
    private readonly IEmailService _emailService;
    
    public async Task Handle(
        OrderConfirmedEvent notification,
        CancellationToken cancellationToken)
    {
        // Publish to message bus for other services
        await _messageBus.PublishAsync(notification);
        
        // Send confirmation email
        await _emailService.SendOrderConfirmationAsync(
            notification.CustomerId,
            notification.OrderId
        );
    }
}

// Product.Application/EventHandlers/OrderConfirmedEventHandler.cs
// (In Product Service - listening to OrderConfirmedEvent)
public class OrderConfirmedEventHandler 
    : IIntegrationEventHandler<OrderConfirmedEvent>
{
    private readonly IProductRepository _repository;
    
    public async Task HandleAsync(OrderConfirmedEvent @event)
    {
        // Reduce stock for ordered products
        // This is handled in Product Service
    }
}
```

### 4. Frontend (React)

```typescript
// src/features/products/ProductList.tsx
import React, { useEffect, useState } from 'react';
import { useQuery } from 'react-query';
import { productApi } from '../../api/productApi';

interface Product {
  id: string;
  name: string;
  description: string;
  price: number;
  currency: string;
  imageUrl: string;
}

export const ProductList: React.FC = () => {
  const { data, isLoading, error } = useQuery(
    ['products'],
    () => productApi.getProducts({ page: 1, pageSize: 20 })
  );

  if (isLoading) return <div>Loading...</div>;
  if (error) return <div>Error loading products</div>;

  return (
    <div className="grid grid-cols-4 gap-4">
      {data?.items.map((product: Product) => (
        <ProductCard key={product.id} product={product} />
      ))}
    </div>
  );
};

// src/features/cart/useCart.ts
import { create } from 'zustand';

interface CartItem {
  productId: string;
  name: string;
  price: number;
  quantity: number;
}

interface CartStore {
  items: CartItem[];
  addItem: (item: CartItem) => void;
  removeItem: (productId: string) => void;
  clearCart: () => void;
  total: () => number;
}

export const useCart = create<CartStore>((set, get) => ({
  items: [],
  
  addItem: (item) => set((state) => ({
    items: [...state.items, item]
  })),
  
  removeItem: (productId) => set((state) => ({
    items: state.items.filter(i => i.productId !== productId)
  })),
  
  clearCart: () => set({ items: [] }),
  
  total: () => get().items.reduce(
    (sum, item) => sum + item.price * item.quantity,
    0
  )
}));
```

### 5. Infrastructure

**Docker Compose:**

```yaml
version: '3.8'

services:
  # API Gateway
  gateway:
    build: ./src/ApiGateway
    ports:
      - "5000:80"
    depends_on:
      - product-service
      - order-service
    environment:
      - ASPNETCORE_ENVIRONMENT=Development
  
  # Product Service
  product-service:
    build: ./src/Services/Product/Product.API
    environment:
      - ConnectionStrings__DefaultConnection=Host=postgres;Database=ProductDb;Username=postgres;Password=postgres
      - Redis__Connection=redis:6379
    depends_on:
      - postgres
      - redis
  
  # Order Service
  order-service:
    build: ./src/Services/Order/Order.API
    environment:
      - ConnectionStrings__DefaultConnection=Host=postgres;Database=OrderDb;Username=postgres;Password=postgres
      - RabbitMQ__Host=rabbitmq
    depends_on:
      - postgres
      - rabbitmq
  
  # Databases
  postgres:
    image: postgres:15-alpine
    environment:
      - POSTGRES_PASSWORD=postgres
    volumes:
      - postgres-data:/var/lib/postgresql/data
  
  redis:
    image: redis:7-alpine
  
  rabbitmq:
    image: rabbitmq:3-management
    ports:
      - "15672:15672"

volumes:
  postgres-data:
```

### 6. Testing

```csharp
// Product.Tests/Domain/ProductTests.cs
public class ProductTests
{
    [Fact]
    public void Create_WithValidData_ShouldSucceed()
    {
        // Arrange
        var name = "iPhone 15";
        var price = new Money(999, "USD");
        
        // Act
        var product = Product.Create(name, "...", price, 100, category);
        
        // Assert
        product.Should().NotBeNull();
        product.Name.Should().Be(name);
        product.Price.Should().Be(price);
        product.Status.Should().Be(ProductStatus.Draft);
    }
    
    [Fact]
    public void Publish_WithoutName_ShouldThrowException()
    {
        // Arrange
        var product = Product.Create("", "...", new Money(10, "USD"), 1, category);
        
        // Act & Assert
        Assert.Throws<DomainException>(() => product.Publish());
    }
}

// Product.Tests/Application/CreateProductCommandHandlerTests.cs
public class CreateProductCommandHandlerTests
{
    [Fact]
    public async Task Handle_WithValidCommand_ShouldCreateProduct()
    {
        // Arrange
        var repository = new Mock<IProductRepository>();
        var unitOfWork = new Mock<IUnitOfWork>();
        var handler = new CreateProductCommandHandler(repository.Object, unitOfWork.Object);
        
        var command = new CreateProductCommand("iPhone", "...", 999, "USD", 100, categoryId);
        
        // Act
        var result = await handler.Handle(command, CancellationToken.None);
        
        // Assert
        result.Should().NotBeEmpty();
        repository.Verify(r => r.AddAsync(It.IsAny<Product>()), Times.Once);
        unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }
}
```

---

## Project 2: Social Media Clone (Instagram)

### Key Features:
- User authentication (JWT)
- Photo upload (S3)
- Feed generation (Redis)
- Like/Comment (Real-time with SignalR)
- Follow/Unfollow
- Stories (24h expiry)

### Architecture Highlights:

```csharp
// Feed Generation (Fan-out on Write)
public class FeedService
{
    public async Task OnPhotoPostedAsync(Photo photo)
    {
        var followers = await _userRepository.GetFollowersAsync(photo.UserId);
        
        var tasks = followers.Select(follower =>
            _cache.ListPushAsync($"feed:{follower.Id}", photo.Id)
        );
        
        await Task.WhenAll(tasks);
    }
}

// Real-time Notifications (SignalR)
public class NotificationHub : Hub
{
    public async Task SendLikeNotification(string userId, string photoId)
    {
        await Clients.User(userId).SendAsync("ReceiveLike", photoId);
    }
}
```

---

## Project 3: Task Management System (Jira Clone)

### Key Features:
- Projects & Boards (Kanban)
- Tasks (Stories, Bugs, Tasks)
- Sprints
- Comments & Attachments
- Real-time collaboration

### Domain Model:

```csharp
public class Board : AggregateRoot
{
    public string Name { get; private set; }
    public List<Column> Columns { get; private set; }
    public List<Task> Tasks { get; private set; }
    
    public void MoveTask(Guid taskId, Guid targetColumnId)
    {
        var task = Tasks.FirstOrDefault(t => t.Id == taskId);
        if (task == null)
            throw new NotFoundException("Task not found");
            
        var column = Columns.FirstOrDefault(c => c.Id == targetColumnId);
        if (column == null)
            throw new NotFoundException("Column not found");
            
        task.MoveToColumn(targetColumnId);
        AddDomainEvent(new TaskMovedEvent(taskId, targetColumnId));
    }
}
```

---

## Project 4: Streaming Platform (YouTube Clone)

### Key Features:
- Video upload (Chunked)
- Video transcoding (FFmpeg)
- Adaptive streaming (HLS)
- Recommendations (ML.NET)
- Comments & Likes

### Video Processing Pipeline:

```csharp
public class VideoProcessingService
{
    public async Task ProcessVideoAsync(Guid videoId, Stream videoStream)
    {
        // 1. Upload to S3
        var s3Key = await UploadToS3Async(videoStream);
        
        // 2. Queue transcoding job
        await _messageQueue.EnqueueAsync(new TranscodeVideoCommand
        {
            VideoId = videoId,
            S3Key = s3Key,
            Resolutions = new[] { "360p", "720p", "1080p" }
        });
        
        // 3. Generate thumbnail
        await GenerateThumbnailAsync(videoId, videoStream);
    }
}
```

---

## Best Practices Summary

### 1. Clean Architecture
✅ Separate concerns into layers
✅ Dependencies point inward
✅ Domain logic independent

### 2. DDD
✅ Rich domain models
✅ Aggregates for consistency
✅ Domain events for decoupling

### 3. CQRS
✅ Separate read/write models
✅ Optimize queries separately
✅ Event sourcing when needed

### 4. Microservices
✅ Bounded contexts
✅ API Gateway
✅ Service discovery
✅ Circuit breaker

### 5. Testing
✅ Unit tests (80%+ coverage)
✅ Integration tests
✅ E2E tests for critical flows

### 6. Performance
✅ Caching (Redis)
✅ CDN for static files
✅ Database indexing
✅ Async operations

### 7. Security
✅ Authentication (JWT)
✅ Authorization (RBAC)
✅ Input validation
✅ HTTPS everywhere

---

## Deployment Checklist

- [ ] Docker images built
- [ ] Kubernetes manifests ready
- [ ] CI/CD pipeline configured
- [ ] Monitoring set up (Prometheus + Grafana)
- [ ] Logging configured (ELK)
- [ ] Backups automated
- [ ] Load testing completed
- [ ] Security scan passed
- [ ] Documentation complete

---

## Resources

### GitHub Repositories:
- [eShopOnContainers](https://github.com/dotnet-architecture/eShopOnContainers)
- [Clean Architecture](https://github.com/jasontaylordev/CleanArchitecture)
- [Modular Monolith](https://github.com/kgrzybek/modular-monolith-with-ddd)

### Learn More:
- Martin Fowler - Enterprise Application Patterns
- Microsoft Docs - .NET Microservices
- AWS Well-Architected Framework

---

**Omad! Real loyihalar sizni senior qiladi! 🚀**
