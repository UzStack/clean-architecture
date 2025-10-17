# System Design - Senior Developer Uchun

System Design - bu katta miqyosda tizimlarni loyihalash san'ati.

---

## System Design Intervyularda

Senior developer sifatida System Design intervyularidan o'tish kerak. Bu sizning:
- ✅ Katta tizimlar loyihalash qobiliyatingizni
- ✅ Trade-off'larni tushunishingizni
- ✅ Scalability haqida bilimingizni
- ✅ Real dunyo tajribangizni ko'rsatadi

---

## Asosiy Konseptlar

### 1. Scalability (Kengayuvchanlik)

**Vertical Scaling (Vertikal) - Scale Up:**
```
┌──────────┐      ┌──────────┐
│  4 CPU   │  →   │  16 CPU  │
│  8 GB    │      │  64 GB   │
│  SSD     │      │  NVMe    │
└──────────┘      └──────────┘
```

**Horizontal Scaling (Gorizontal) - Scale Out:**
```
┌──────────┐      ┌──────────┐ ┌──────────┐ ┌──────────┐
│  Server  │  →   │ Server 1 │ │ Server 2 │ │ Server 3 │
└──────────┘      └──────────┘ └──────────┘ └──────────┘
                         ↑            ↑            ↑
                    Load Balancer
```

**Qachon qaysi biri?**

| Vertical Scaling | Horizontal Scaling |
|------------------|-------------------|
| Tez va oson | Murakkab |
| Limit bor | Deyarli cheksiz |
| Downtime kerak | Zero downtime |
| Qimmat | Arzon |
| Database uchun yaxshi | Application uchun yaxshi |

---

### 2. Load Balancing

**Maqsad:** Trafikni bir necha serverga taqsimlash

```
                    Internet
                       ↓
                ┌─────────────┐
                │Load Balancer│
                └─────────────┘
                   ↙    ↓    ↘
          Server1  Server2  Server3
```

**Load Balancing Algoritmlari:**

```csharp
// Round Robin - Navbat bilan
public class RoundRobinLoadBalancer
{
    private List<Server> _servers;
    private int _currentIndex = 0;
    
    public Server GetNextServer()
    {
        var server = _servers[_currentIndex];
        _currentIndex = (_currentIndex + 1) % _servers.Count;
        return server;
    }
}

// Least Connections - Eng kam ulanishlar
public class LeastConnectionsLoadBalancer
{
    private List<Server> _servers;
    
    public Server GetNextServer()
    {
        return _servers
            .OrderBy(s => s.ActiveConnections)
            .First();
    }
}

// Weighted Round Robin - Og'irlik bilan
public class WeightedLoadBalancer
{
    private List<(Server server, int weight)> _servers;
    
    public Server GetNextServer()
    {
        // Og'irlikka qarab taqsimlash
        var totalWeight = _servers.Sum(s => s.weight);
        var random = new Random().Next(totalWeight);
        
        int current = 0;
        foreach (var (server, weight) in _servers)
        {
            current += weight;
            if (random < current)
                return server;
        }
        
        return _servers[0].server;
    }
}
```

---

### 3. Caching Strategiyalari

**Cache Layers:**
```
Browser Cache
     ↓
CDN Cache
     ↓
Application Cache (Redis)
     ↓
Database Cache
     ↓
Database
```

**Caching Patterns:**

```csharp
// Cache-Aside (Lazy Loading)
public async Task<Product> GetProductAsync(int id)
{
    // 1. Cache'dan olishga harakat
    var cached = await _cache.GetAsync<Product>($"product:{id}");
    if (cached != null)
        return cached;
    
    // 2. Database'dan olish
    var product = await _database.GetProductAsync(id);
    
    // 3. Cache'ga qo'yish
    await _cache.SetAsync($"product:{id}", product, TimeSpan.FromHours(1));
    
    return product;
}

// Write-Through
public async Task UpdateProductAsync(Product product)
{
    // 1. Database'ga yozish
    await _database.UpdateAsync(product);
    
    // 2. Cache'ni yangilash
    await _cache.SetAsync($"product:{product.Id}", product, TimeSpan.FromHours(1));
}

// Write-Behind (Write-Back)
public async Task UpdateProductAsync(Product product)
{
    // 1. Faqat cache'ga yozish
    await _cache.SetAsync($"product:{product.Id}", product);
    
    // 2. Database'ga yozish queue orqali (async)
    await _queue.EnqueueAsync(new UpdateProductCommand(product));
}
```

**Cache Invalidation:**
```csharp
// TTL (Time To Live)
await _cache.SetAsync("key", value, TimeSpan.FromMinutes(5));

// Manual Invalidation
public async Task UpdateProductAsync(Product product)
{
    await _database.UpdateAsync(product);
    await _cache.RemoveAsync($"product:{product.Id}");
}

// Event-based Invalidation
public class ProductUpdatedEventHandler
{
    private readonly ICacheService _cache;
    
    public async Task Handle(ProductUpdatedEvent @event)
    {
        await _cache.RemoveAsync($"product:{@event.ProductId}");
    }
}
```

---

### 4. Database Sharding

**Maqsad:** Katta database'ni kichik qismlarga bo'lish

**Horizontal Sharding:**
```
Users Table
     ↓
┌────────────────┐
│  Shard by ID   │
└────────────────┘
     ↓
ID 1-1000000    → Shard 1
ID 1000001-2000000 → Shard 2
ID 2000001+     → Shard 3
```

```csharp
public class ShardingService
{
    private Dictionary<int, DbConnection> _shards;
    
    public DbConnection GetShardForUser(int userId)
    {
        // Hash-based sharding
        var shardId = userId % _shards.Count;
        return _shards[shardId];
    }
    
    // Range-based sharding
    public DbConnection GetShardByRange(int userId)
    {
        if (userId <= 1000000)
            return _shards[0];
        else if (userId <= 2000000)
            return _shards[1];
        else
            return _shards[2];
    }
}
```

---

### 5. CAP Theorem

**Qoida:** Distributed sistemada faqat 2 tasini tanlash mumkin:

```
        Consistency
           ╱  ╲
          ╱    ╲
         ╱  CA  ╲
        ╱────────╲
Availability   Partition Tolerance
```

- **C** - Consistency (Izchillik)
- **A** - Availability (Mavjudlik)
- **P** - Partition Tolerance (Bo'linish bardoshliligi)

**Misollar:**
- **CP Systems:** MongoDB, HBase, Redis (master-slave)
- **AP Systems:** Cassandra, DynamoDB, CouchDB
- **CA Systems:** MySQL, PostgreSQL (single server)

---

### 6. Message Queue

**Maqsad:** Async communication

```
Producer → Queue → Consumer
```

```csharp
// RabbitMQ misoli
public class OrderService
{
    private readonly IMessageQueue _queue;
    
    public async Task CreateOrderAsync(Order order)
    {
        // 1. Order yaratish
        await _repository.AddAsync(order);
        
        // 2. Message yuborish (async)
        await _queue.PublishAsync(new OrderCreatedEvent
        {
            OrderId = order.Id,
            CustomerId = order.CustomerId,
            TotalAmount = order.TotalAmount
        });
    }
}

// Consumer
public class OrderCreatedEventConsumer : IConsumer<OrderCreatedEvent>
{
    public async Task ConsumeAsync(OrderCreatedEvent @event)
    {
        // Email yuborish
        await SendEmailAsync(@event.CustomerId);
        
        // Inventory reserve qilish
        await ReserveInventoryAsync(@event.OrderId);
        
        // Analytics ga yuborish
        await TrackOrderAsync(@event);
    }
}
```

---

### 7. Microservices Architecture

```
API Gateway
     ↓
┌────────────────────────────────┐
│  Service Mesh                  │
├────────────┬────────┬──────────┤
│  Order     │ Payment│ Inventory│
│  Service   │ Service│ Service  │
└────────────┴────────┴──────────┘
```

**Key Patterns:**

```csharp
// API Gateway Pattern
public class ApiGateway
{
    public async Task<OrderResponse> GetOrderDetails(int orderId)
    {
        // 1. Order service'dan order olish
        var order = await _orderService.GetOrderAsync(orderId);
        
        // 2. Customer service'dan customer olish
        var customer = await _customerService.GetCustomerAsync(order.CustomerId);
        
        // 3. Payment service'dan payment olish
        var payment = await _paymentService.GetPaymentAsync(orderId);
        
        // 4. Aggregate qilish
        return new OrderResponse
        {
            Order = order,
            Customer = customer,
            Payment = payment
        };
    }
}

// Circuit Breaker Pattern
public class CircuitBreaker
{
    private int _failureCount = 0;
    private DateTime _lastFailureTime;
    private CircuitState _state = CircuitState.Closed;
    
    public async Task<T> ExecuteAsync<T>(Func<Task<T>> action)
    {
        if (_state == CircuitState.Open)
        {
            if (DateTime.UtcNow - _lastFailureTime > TimeSpan.FromSeconds(30))
            {
                _state = CircuitState.HalfOpen;
            }
            else
            {
                throw new CircuitBreakerOpenException();
            }
        }
        
        try
        {
            var result = await action();
            _failureCount = 0;
            _state = CircuitState.Closed;
            return result;
        }
        catch
        {
            _failureCount++;
            _lastFailureTime = DateTime.UtcNow;
            
            if (_failureCount >= 5)
                _state = CircuitState.Open;
                
            throw;
        }
    }
}

enum CircuitState { Closed, Open, HalfOpen }
```

---

## Real System Design Masala

### Masala: Instagram kabi Photo Sharing App loyihalang

**Requirements:**
- 500M active users
- 100M photos per day
- Users can upload, view, like, comment
- Feed generation

**1. Capacity Estimation:**
```
Users: 500M
Daily Photos: 100M
Average Photo Size: 2MB

Storage per day: 100M * 2MB = 200TB/day
Storage per year: 200TB * 365 = 73PB/year

Bandwidth:
Upload: 100M photos/day / 86400 seconds = 1157 photos/sec
        1157 * 2MB = 2.3GB/sec

Read:Write Ratio: 100:1 (ko'proq o'qiladi)
Read Bandwidth: 2.3GB/sec * 100 = 230GB/sec
```

**2. API Design:**
```csharp
// Upload Photo
POST /api/photos
{
    "image": "base64_or_url",
    "caption": "string",
    "location": "lat,long"
}

// Get Feed
GET /api/feed?userId=123&page=1&limit=20

// Like Photo
POST /api/photos/{photoId}/like

// Comment
POST /api/photos/{photoId}/comments
{
    "text": "comment text"
}
```

**3. Database Schema:**
```sql
-- Users table
CREATE TABLE users (
    user_id BIGINT PRIMARY KEY,
    username VARCHAR(50) UNIQUE,
    email VARCHAR(100),
    created_at TIMESTAMP
);

-- Photos table (sharded by user_id)
CREATE TABLE photos (
    photo_id BIGINT PRIMARY KEY,
    user_id BIGINT,
    image_url VARCHAR(500),
    caption TEXT,
    created_at TIMESTAMP,
    INDEX (user_id, created_at)
);

-- Likes table (sharded by photo_id)
CREATE TABLE likes (
    user_id BIGINT,
    photo_id BIGINT,
    created_at TIMESTAMP,
    PRIMARY KEY (user_id, photo_id)
);

-- Comments table
CREATE TABLE comments (
    comment_id BIGINT PRIMARY KEY,
    photo_id BIGINT,
    user_id BIGINT,
    text TEXT,
    created_at TIMESTAMP,
    INDEX (photo_id, created_at)
);

-- Followers table (sharded by user_id)
CREATE TABLE followers (
    follower_id BIGINT,
    followee_id BIGINT,
    created_at TIMESTAMP,
    PRIMARY KEY (follower_id, followee_id)
);
```

**4. High-Level Design:**
```
┌──────────┐
│  Client  │
└────┬─────┘
     │
┌────▼─────────┐
│ Load Balancer│
└────┬─────────┘
     │
┌────▼──────────┐
│  API Gateway  │
└────┬──────────┘
     │
┌────┴─────┬───────────┬──────────┬──────────┐
│          │           │          │          │
▼          ▼           ▼          ▼          ▼
Photo    Feed      Like/      User      Notification
Service  Service   Comment    Service    Service
                   Service
```

**5. Feed Generation:**
```csharp
// Fan-out on Write (Push model)
public class FeedService
{
    public async Task OnPhotoUploaded(Photo photo)
    {
        // 1. User'ning follower'larini olish
        var followers = await GetFollowersAsync(photo.UserId);
        
        // 2. Har bir follower'ning feed'iga qo'shish
        foreach (var follower in followers)
        {
            await _cache.ListPushAsync(
                $"feed:{follower.Id}", 
                photo.Id
            );
        }
    }
    
    // Feed olish
    public async Task<List<Photo>> GetFeedAsync(long userId, int page, int limit)
    {
        var photoIds = await _cache.ListRangeAsync(
            $"feed:{userId}",
            page * limit,
            (page + 1) * limit
        );
        
        return await GetPhotosByIdsAsync(photoIds);
    }
}

// Fan-out on Read (Pull model) - Celebrity users uchun
public class CelebrityFeedService
{
    public async Task<List<Photo>> GetFeedAsync(long userId)
    {
        // 1. Following'larni olish
        var following = await GetFollowingAsync(userId);
        
        // 2. Har biridan eng so'nggi photo'larni olish
        var tasks = following.Select(f => 
            GetRecentPhotosAsync(f.Id, limit: 10)
        );
        
        var results = await Task.WhenAll(tasks);
        
        // 3. Merge qilish va sort qilish
        return results
            .SelectMany(r => r)
            .OrderByDescending(p => p.CreatedAt)
            .Take(100)
            .ToList();
    }
}
```

**6. Image Storage:**
```
Upload Flow:
1. Client → API Server
2. API Server → S3/CDN
3. Generate thumbnails (async)
4. Update database with URLs

┌────────┐      ┌──────────┐      ┌─────┐
│ Client │─────→│API Server│─────→│ S3  │
└────────┘      └────┬─────┘      └─────┘
                     │
                     ▼
              ┌──────────────┐
              │Image Processor│
              │(Thumbnails)   │
              └───────────────┘
```

---

## System Design Interview Tips

### Framework (7 qadam):

1. **Requirements Clarification** (5 min)
   - Functional requirements
   - Non-functional requirements
   - Users, scale

2. **Capacity Estimation** (5 min)
   - Traffic
   - Storage
   - Bandwidth

3. **API Design** (5 min)
   - Endpoints
   - Request/Response

4. **Database Design** (10 min)
   - Schema
   - Sharding strategy

5. **High-Level Design** (15 min)
   - Components
   - Data flow

6. **Detailed Design** (15 min)
   - Bottlenecks
   - Trade-offs

7. **Scaling & Optimization** (5 min)
   - Caching
   - Load balancing
   - Replication

---

## Keyingi Qadamlar

System Design'ni o'rgandingiz! Endi:

1. **Performance Optimization** - Tezlashtirish
2. **Security** - Xavfsizlik
3. **Real Projects** - Amaliy loyihalar

**Mashq:** Quyidagi tizimlarni loyihalang:
- Twitter
- Uber
- WhatsApp
- YouTube
- Amazon

Keyingi: [Performance Optimization](./07-performance.md)
