# Performance Optimization - Tezlashtirish San'ati

Performance - bu foydalanuvchi tajribasining eng muhim qismi.

---

## Performance Metrics

### Core Web Vitals

**1. LCP (Largest Contentful Paint)**
- Eng katta kontent qachon yuklanadi
- Yaxshi: < 2.5s
- O'rtacha: 2.5s - 4s
- Yomon: > 4s

**2. FID (First Input Delay)**
- Birinchi interaction qancha vaqt oladi
- Yaxshi: < 100ms
- O'rtacha: 100ms - 300ms
- Yomon: > 300ms

**3. CLS (Cumulative Layout Shift)**
- Layout qancha o'zgaradi
- Yaxshi: < 0.1
- O'rtacha: 0.1 - 0.25
- Yomon: > 0.25

---

## Database Optimization

### 1. Indexing

```sql
-- Without Index (Slow)
SELECT * FROM users WHERE email = 'test@example.com';
-- Full table scan: 1,000,000 rows

-- With Index (Fast)
CREATE INDEX idx_users_email ON users(email);
SELECT * FROM users WHERE email = 'test@example.com';
-- Index scan: 1 row
```

**Index turlari:**

```sql
-- Single Column Index
CREATE INDEX idx_lastname ON users(lastname);

-- Composite Index
CREATE INDEX idx_name ON users(firstname, lastname);

-- Unique Index
CREATE UNIQUE INDEX idx_email ON users(email);

-- Partial Index
CREATE INDEX idx_active_users ON users(email) 
WHERE is_active = true;

-- Full-Text Index
CREATE FULLTEXT INDEX idx_description ON products(description);
```

**Index qachon ishlatilmaydi:**

```csharp
// ❌ Yomon - Function ishlatilgan
var users = await _context.Users
    .Where(u => u.CreatedAt.Year == 2024)
    .ToListAsync();

// ✅ Yaxshi - Index ishlatiladi
var startDate = new DateTime(2024, 1, 1);
var endDate = new DateTime(2024, 12, 31);
var users = await _context.Users
    .Where(u => u.CreatedAt >= startDate && u.CreatedAt <= endDate)
    .ToListAsync();

// ❌ Yomon - Leading wildcard
SELECT * FROM products WHERE name LIKE '%phone%';

// ✅ Yaxshi - Trailing wildcard
SELECT * FROM products WHERE name LIKE 'phone%';
```

---

### 2. Query Optimization

```csharp
// ❌ N+1 Problem
public async Task<List<OrderDto>> GetOrdersAsync()
{
    var orders = await _context.Orders.ToListAsync();
    
    foreach (var order in orders)
    {
        // Har bir order uchun alohida query!
        order.Customer = await _context.Customers
            .FindAsync(order.CustomerId);
    }
    
    return orders;
}

// ✅ Eager Loading
public async Task<List<OrderDto>> GetOrdersAsync()
{
    return await _context.Orders
        .Include(o => o.Customer)
        .Include(o => o.OrderItems)
            .ThenInclude(oi => oi.Product)
        .ToListAsync();
}

// ✅ Explicit Loading (lazy load kerak bo'lganda)
public async Task<Order> GetOrderAsync(int id)
{
    var order = await _context.Orders.FindAsync(id);
    
    if (needCustomerInfo)
    {
        await _context.Entry(order)
            .Reference(o => o.Customer)
            .LoadAsync();
    }
    
    return order;
}

// ✅ Select Only What You Need
public async Task<List<OrderSummaryDto>> GetOrderSummariesAsync()
{
    return await _context.Orders
        .Select(o => new OrderSummaryDto
        {
            OrderId = o.Id,
            CustomerName = o.Customer.Name,
            TotalAmount = o.TotalAmount
        })
        .ToListAsync();
}
```

**Batch Operations:**

```csharp
// ❌ Yomon - Har birini alohida insert
public async Task AddProductsAsync(List<Product> products)
{
    foreach (var product in products)
    {
        await _context.Products.AddAsync(product);
        await _context.SaveChangesAsync(); // Har safar DB ga!
    }
}

// ✅ Yaxshi - Batch insert
public async Task AddProductsAsync(List<Product> products)
{
    await _context.Products.AddRangeAsync(products);
    await _context.SaveChangesAsync(); // Bir marta!
}

// ✅ Bulk Operations (EFCore.BulkExtensions)
public async Task UpdateProductsAsync(List<Product> products)
{
    await _context.BulkUpdateAsync(products);
}
```

---

### 3. Database Sharding & Partitioning

**Horizontal Partitioning (Sharding):**

```csharp
public class ShardedRepository
{
    private readonly Dictionary<int, DbContext> _shards;
    
    public async Task<User> GetUserAsync(int userId)
    {
        var shardId = GetShardId(userId);
        var context = _shards[shardId];
        
        return await context.Users.FindAsync(userId);
    }
    
    private int GetShardId(int userId)
    {
        // Hash-based sharding
        return userId % _shards.Count;
    }
}
```

**Vertical Partitioning:**

```sql
-- User asosiy ma'lumotlar (tez-tez ishlatiladi)
CREATE TABLE users (
    user_id INT PRIMARY KEY,
    username VARCHAR(50),
    email VARCHAR(100),
    created_at TIMESTAMP
);

-- User qo'shimcha ma'lumotlar (kamdan-kam)
CREATE TABLE user_profiles (
    user_id INT PRIMARY KEY,
    bio TEXT,
    avatar_url VARCHAR(500),
    settings JSON,
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);
```

---

## Application-Level Optimization

### 1. Caching Strategies

```csharp
// Memory Cache (In-Process)
public class ProductService
{
    private readonly IMemoryCache _cache;
    private readonly IProductRepository _repository;
    
    public async Task<Product> GetProductAsync(int id)
    {
        return await _cache.GetOrCreateAsync(
            $"product:{id}",
            async entry =>
            {
                entry.AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(10);
                entry.SlidingExpiration = TimeSpan.FromMinutes(5);
                return await _repository.GetByIdAsync(id);
            }
        );
    }
}

// Distributed Cache (Redis)
public class CachedProductService
{
    private readonly IDistributedCache _cache;
    private readonly IProductRepository _repository;
    
    public async Task<Product> GetProductAsync(int id)
    {
        var cacheKey = $"product:{id}";
        
        // Try get from cache
        var cached = await _cache.GetStringAsync(cacheKey);
        if (cached != null)
        {
            return JsonSerializer.Deserialize<Product>(cached);
        }
        
        // Get from DB
        var product = await _repository.GetByIdAsync(id);
        
        // Set cache
        await _cache.SetStringAsync(
            cacheKey,
            JsonSerializer.Serialize(product),
            new DistributedCacheEntryOptions
            {
                AbsoluteExpirationRelativeToNow = TimeSpan.FromHours(1)
            }
        );
        
        return product;
    }
}

// Cache Invalidation
public class ProductService
{
    public async Task UpdateProductAsync(Product product)
    {
        // Update DB
        await _repository.UpdateAsync(product);
        
        // Invalidate cache
        await _cache.RemoveAsync($"product:{product.Id}");
        
        // Or update cache
        await SetCacheAsync($"product:{product.Id}", product);
    }
}
```

**Cache Patterns:**

```csharp
// Cache-Aside (Lazy Loading)
public async Task<T> GetWithCacheAside<T>(string key, Func<Task<T>> getData)
{
    var cached = await _cache.GetAsync<T>(key);
    if (cached != null) return cached;
    
    var data = await getData();
    await _cache.SetAsync(key, data, TimeSpan.FromMinutes(10));
    return data;
}

// Read-Through
public class ReadThroughCache<T>
{
    public async Task<T> GetAsync(string key)
    {
        // Cache internally fetches from DB if miss
        return await _cache.GetAsync(key, async () => 
            await _database.GetAsync(key)
        );
    }
}

// Write-Through
public async Task UpdateAsync(T entity)
{
    await _database.UpdateAsync(entity);
    await _cache.SetAsync(GetKey(entity), entity);
}

// Write-Behind (Async write to DB)
public async Task UpdateAsync(T entity)
{
    await _cache.SetAsync(GetKey(entity), entity);
    await _queue.EnqueueAsync(new UpdateCommand(entity));
}
```

---

### 2. Async/Await Best Practices

```csharp
// ❌ Sync over Async - blocking!
public User GetUser(int id)
{
    return _repository.GetUserAsync(id).Result; // Deadlock!
}

// ✅ Pure async
public async Task<User> GetUserAsync(int id)
{
    return await _repository.GetUserAsync(id);
}

// ❌ Async void (faqat event handler'da)
public async void ProcessOrderAsync(int orderId) // ❌
{
    await _processor.ProcessAsync(orderId);
}

// ✅ Async Task
public async Task ProcessOrderAsync(int orderId)
{
    await _processor.ProcessAsync(orderId);
}

// Parallel execution
public async Task<OrderDetails> GetOrderDetailsAsync(int orderId)
{
    // ❌ Sequential - slow
    var order = await _orderRepository.GetAsync(orderId);
    var customer = await _customerRepository.GetAsync(order.CustomerId);
    var items = await _itemRepository.GetByOrderAsync(orderId);
    
    // ✅ Parallel - fast
    var orderTask = _orderRepository.GetAsync(orderId);
    var customerTask = _customerRepository.GetAsync(order.CustomerId);
    var itemsTask = _itemRepository.GetByOrderAsync(orderId);
    
    await Task.WhenAll(orderTask, customerTask, itemsTask);
    
    return new OrderDetails
    {
        Order = orderTask.Result,
        Customer = customerTask.Result,
        Items = itemsTask.Result
    };
}
```

---

### 3. Lazy Loading & Pagination

```csharp
// Pagination
public async Task<PagedResult<Product>> GetProductsAsync(
    int page = 1, 
    int pageSize = 20)
{
    var query = _context.Products.AsQueryable();
    
    var total = await query.CountAsync();
    
    var items = await query
        .Skip((page - 1) * pageSize)
        .Take(pageSize)
        .ToListAsync();
    
    return new PagedResult<Product>
    {
        Items = items,
        Page = page,
        PageSize = pageSize,
        TotalCount = total,
        TotalPages = (int)Math.Ceiling(total / (double)pageSize)
    };
}

// Cursor-based pagination (better for large datasets)
public async Task<CursorResult<Product>> GetProductsAsync(
    string cursor = null,
    int limit = 20)
{
    var query = _context.Products.OrderBy(p => p.Id);
    
    if (!string.IsNullOrEmpty(cursor))
    {
        var cursorId = int.Parse(cursor);
        query = query.Where(p => p.Id > cursorId);
    }
    
    var items = await query.Take(limit + 1).ToListAsync();
    
    var hasMore = items.Count > limit;
    if (hasMore)
    {
        items = items.Take(limit).ToList();
    }
    
    var nextCursor = hasMore ? items.Last().Id.ToString() : null;
    
    return new CursorResult<Product>
    {
        Items = items,
        NextCursor = nextCursor,
        HasMore = hasMore
    };
}

// Lazy Loading with IAsyncEnumerable
public async IAsyncEnumerable<Product> StreamProductsAsync()
{
    await foreach (var product in _context.Products.AsAsyncEnumerable())
    {
        yield return product;
    }
}

// Usage
await foreach (var product in _service.StreamProductsAsync())
{
    await ProcessProductAsync(product);
}
```

---

### 4. Object Pooling

```csharp
// ArrayPool - array'lar uchun
public class ImageProcessor
{
    public async Task<byte[]> ProcessImageAsync(Stream input)
    {
        var buffer = ArrayPool<byte>.Shared.Rent(4096);
        try
        {
            int bytesRead;
            while ((bytesRead = await input.ReadAsync(buffer, 0, buffer.Length)) > 0)
            {
                // Process buffer
            }
            
            return buffer;
        }
        finally
        {
            ArrayPool<byte>.Shared.Return(buffer);
        }
    }
}

// HttpClient Pool
public class Startup
{
    public void ConfigureServices(IServiceCollection services)
    {
        services.AddHttpClient<IApiClient, ApiClient>()
            .SetHandlerLifetime(TimeSpan.FromMinutes(5))
            .AddPolicyHandler(GetRetryPolicy());
    }
    
    private static IAsyncPolicy<HttpResponseMessage> GetRetryPolicy()
    {
        return HttpPolicyExtensions
            .HandleTransientHttpError()
            .WaitAndRetryAsync(3, retryAttempt => 
                TimeSpan.FromSeconds(Math.Pow(2, retryAttempt)));
    }
}

// Custom Object Pool
public class ObjectPool<T> where T : class, new()
{
    private readonly ConcurrentBag<T> _objects = new();
    private readonly Func<T> _objectGenerator;
    
    public ObjectPool(Func<T> objectGenerator = null)
    {
        _objectGenerator = objectGenerator ?? (() => new T());
    }
    
    public T Rent()
    {
        return _objects.TryTake(out T item) ? item : _objectGenerator();
    }
    
    public void Return(T item)
    {
        _objects.Add(item);
    }
}

// Usage
public class ExpensiveService
{
    private static readonly ObjectPool<StringBuilder> _pool = 
        new ObjectPool<StringBuilder>();
    
    public string BuildString()
    {
        var sb = _pool.Rent();
        try
        {
            sb.Clear();
            sb.Append("Hello");
            sb.Append(" ");
            sb.Append("World");
            return sb.ToString();
        }
        finally
        {
            _pool.Return(sb);
        }
    }
}
```

---

## Frontend Optimization

### 1. Lazy Loading & Code Splitting

```typescript
// React Lazy Loading
const Dashboard = React.lazy(() => import('./Dashboard'));
const Profile = React.lazy(() => import('./Profile'));

function App() {
  return (
    <Suspense fallback={<Loading />}>
      <Routes>
        <Route path="/dashboard" element={<Dashboard />} />
        <Route path="/profile" element={<Profile />} />
      </Routes>
    </Suspense>
  );
}

// Image Lazy Loading
<img 
  src="image.jpg" 
  loading="lazy" 
  alt="Description"
/>

// Intersection Observer API
const observer = new IntersectionObserver((entries) => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {
      const img = entry.target;
      img.src = img.dataset.src;
      observer.unobserve(img);
    }
  });
});

document.querySelectorAll('img[data-src]').forEach(img => {
  observer.observe(img);
});
```

### 2. Memoization

```typescript
// React.memo
const ProductCard = React.memo(({ product }) => {
  return (
    <div>
      <h3>{product.name}</h3>
      <p>{product.price}</p>
    </div>
  );
});

// useMemo
function ProductList({ products, filter }) {
  const filteredProducts = useMemo(() => {
    return products.filter(p => p.category === filter);
  }, [products, filter]);
  
  return (
    <div>
      {filteredProducts.map(p => <ProductCard key={p.id} product={p} />)}
    </div>
  );
}

// useCallback
function ProductForm() {
  const [name, setName] = useState('');
  
  const handleSubmit = useCallback(async () => {
    await api.createProduct({ name });
  }, [name]);
  
  return (
    <form onSubmit={handleSubmit}>
      <input value={name} onChange={e => setName(e.target.value)} />
    </form>
  );
}
```

---

## Network Optimization

### 1. HTTP/2 & HTTP/3

```
HTTP/1.1: Sequential requests
├── request1 → response1 (500ms)
├── request2 → response2 (500ms)
└── request3 → response3 (500ms)
Total: 1500ms

HTTP/2: Multiplexing
├── request1 ┐
├── request2 ├→ All responses (500ms)
└── request3 ┘
Total: 500ms
```

### 2. CDN (Content Delivery Network)

```
User (Toshkent) → CDN (Toshkent) → Origin (US)
     50ms              500ms
     
Without CDN: 500ms
With CDN: 50ms (90% faster!)
```

### 3. Compression

```csharp
// Gzip/Brotli Compression
public class Startup
{
    public void ConfigureServices(IServiceCollection services)
    {
        services.AddResponseCompression(options =>
        {
            options.EnableForHttps = true;
            options.Providers.Add<BrotliCompressionProvider>();
            options.Providers.Add<GzipCompressionProvider>();
        });
        
        services.Configure<BrotliCompressionProviderOptions>(options =>
        {
            options.Level = CompressionLevel.Fastest;
        });
    }
}

// Results:
// Original: 1MB JSON
// Gzip: 100KB (90% smaller)
// Brotli: 80KB (92% smaller)
```

---

## Profiling & Monitoring

### 1. Application Insights

```csharp
public class ProductService
{
    private readonly TelemetryClient _telemetry;
    
    public async Task<Product> GetProductAsync(int id)
    {
        var sw = Stopwatch.StartNew();
        try
        {
            var product = await _repository.GetAsync(id);
            
            _telemetry.TrackMetric("GetProduct.Duration", sw.ElapsedMilliseconds);
            _telemetry.TrackEvent("GetProduct.Success");
            
            return product;
        }
        catch (Exception ex)
        {
            _telemetry.TrackException(ex);
            _telemetry.TrackEvent("GetProduct.Failed");
            throw;
        }
    }
}
```

### 2. Custom Metrics

```csharp
public class PerformanceMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger _logger;
    
    public async Task InvokeAsync(HttpContext context)
    {
        var sw = Stopwatch.StartNew();
        
        try
        {
            await _next(context);
        }
        finally
        {
            sw.Stop();
            
            _logger.LogInformation(
                "Request {Method} {Path} completed in {Duration}ms with status {StatusCode}",
                context.Request.Method,
                context.Request.Path,
                sw.ElapsedMilliseconds,
                context.Response.StatusCode
            );
            
            // Alert if slow
            if (sw.ElapsedMilliseconds > 1000)
            {
                _logger.LogWarning("Slow request detected!");
            }
        }
    }
}
```

### 3. BenchmarkDotNet

```csharp
[MemoryDiagnoser]
public class StringBenchmarks
{
    [Benchmark]
    public string StringConcatenation()
    {
        string result = "";
        for (int i = 0; i < 1000; i++)
        {
            result += i.ToString();
        }
        return result;
    }
    
    [Benchmark]
    public string StringBuilder()
    {
        var sb = new StringBuilder();
        for (int i = 0; i < 1000; i++)
        {
            sb.Append(i);
        }
        return sb.ToString();
    }
}

// Results:
// StringConcatenation: 1,234.5 ms, 125 MB allocated
// StringBuilder:         12.3 ms,   1 MB allocated
```

---

## Real-World Example: E-Commerce Optimization

### Before Optimization:
```
Page Load Time: 8.5s
Database Queries: 47
Memory Usage: 512MB
Concurrent Users: 100
```

### After Optimization:
```
Page Load Time: 1.2s (7x faster!)
Database Queries: 5
Memory Usage: 128MB (75% less)
Concurrent Users: 1000 (10x more!)
```

**Nima qildik?**

1. **Database:**
   - Added indexes (20 queries → 5 queries)
   - Implemented eager loading
   - Added pagination

2. **Caching:**
   - Redis for product catalog
   - Memory cache for user sessions
   - CDN for static files

3. **Code:**
   - Async/await everywhere
   - Object pooling
   - Lazy loading

4. **Frontend:**
   - Code splitting
   - Image optimization
   - Lazy loading images

---

## Performance Checklist

### Backend:
- [ ] Database indexes qo'shilgan
- [ ] N+1 query muammosi yo'q
- [ ] Caching ishlatilgan
- [ ] Async/await qo'llangan
- [ ] Pagination mavjud
- [ ] Batch operations ishlatilgan

### Frontend:
- [ ] Code splitting
- [ ] Lazy loading
- [ ] Image optimization
- [ ] Memoization
- [ ] Bundle size < 200KB

### Network:
- [ ] HTTP/2 enabled
- [ ] Compression (Gzip/Brotli)
- [ ] CDN configured
- [ ] API response caching

### Monitoring:
- [ ] Application Insights
- [ ] Custom metrics
- [ ] Error tracking
- [ ] Performance alerts

---

## Keyingi Qadamlar

Performance'ni yaxshiladingiz! Endi:

1. **Security** - Xavfsizlik
2. **DevOps** - CI/CD, Docker, Kubernetes
3. **Soft Skills** - Leadership, Communication

**Mashq:** O'z loyihangizni optimize qiling va natijalarni o'lchang!

Keyingi: [Security Best Practices](./08-security.md)
