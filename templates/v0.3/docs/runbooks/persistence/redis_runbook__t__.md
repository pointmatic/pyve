# Redis Operations Runbook

## Overview

Redis is an in-memory data structure store used as a database, cache, message broker, and streaming engine. This runbook provides specific commands and procedures for production Redis operations.

**Key capabilities:**
- In-memory data structures (strings, hashes, lists, sets, sorted sets, streams)
- Sub-millisecond latency
- Persistence options (RDB, AOF)
- Replication (master-replica)
- High availability (Redis Sentinel)
- Clustering (horizontal scaling)
- Pub/Sub messaging
- Lua scripting

**Versions covered:** Redis 6.0+

---

## Installation & Setup

### Installation

**Ubuntu/Debian:**
```bash
# Add Redis repository
curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list

# Install Redis
sudo apt update
sudo apt install redis

# Start service
sudo systemctl start redis-server
sudo systemctl enable redis-server
```

**RHEL/CentOS:**
```bash
# Install EPEL repository
sudo yum install epel-release

# Install Redis
sudo yum install redis

# Start service
sudo systemctl start redis
sudo systemctl enable redis
```

**macOS:**
```bash
# Using Homebrew
brew install redis

# Start service
brew services start redis
```

### Initial Configuration

**Connect to Redis:**
```bash
redis-cli
```

**Basic redis.conf settings:**
```ini
# Network
bind 0.0.0.0
port 6379
protected-mode yes
requirepass your_secure_password

# Memory
maxmemory 2gb
maxmemory-policy allkeys-lru  # Or noeviction, allkeys-lfu, volatile-lru, etc.

# Persistence - RDB (snapshot)
save 900 1      # Save after 900s if 1 key changed
save 300 10     # Save after 300s if 10 keys changed
save 60 10000   # Save after 60s if 10000 keys changed
dbfilename dump.rdb
dir /var/lib/redis

# Persistence - AOF (append-only file)
appendonly yes
appendfilename "appendonly.aof"
appendfsync everysec  # Or always, no

# Logging
loglevel notice
logfile /var/log/redis/redis-server.log

# Limits
maxclients 10000
timeout 300
```

**Restart Redis:**
```bash
sudo systemctl restart redis-server
```

**Connect with authentication:**
```bash
redis-cli -a your_secure_password
# Or
redis-cli
AUTH your_secure_password
```

---

## Backup & Recovery

### RDB Snapshot Backup

**Manual snapshot:**
```bash
# Create snapshot (blocking)
redis-cli SAVE

# Create snapshot (background, non-blocking)
redis-cli BGSAVE

# Check last save time
redis-cli LASTSAVE
```

**Automatic snapshots (redis.conf):**
```ini
save 900 1      # After 900s if 1 key changed
save 300 10     # After 300s if 10 keys changed
save 60 10000   # After 60s if 10000 keys changed
```

**Backup RDB file:**
```bash
# Copy dump.rdb to backup location
cp /var/lib/redis/dump.rdb /backup/redis/dump_$(date +%Y%m%d_%H%M%S).rdb
```

**Restore from RDB:**
```bash
# Stop Redis
sudo systemctl stop redis-server

# Replace dump.rdb
sudo cp /backup/redis/dump_20240115.rdb /var/lib/redis/dump.rdb
sudo chown redis:redis /var/lib/redis/dump.rdb

# Start Redis
sudo systemctl start redis-server
```

### AOF Backup

**Enable AOF (redis.conf):**
```ini
appendonly yes
appendfilename "appendonly.aof"
appendfsync everysec  # Or always (slower, more durable), no (faster, less durable)
```

**Rewrite AOF (compact):**
```bash
# Manual rewrite
redis-cli BGREWRITEAOF

# Check rewrite status
redis-cli INFO persistence | grep aof_rewrite
```

**Automatic rewrite (redis.conf):**
```ini
auto-aof-rewrite-percentage 100  # Rewrite when AOF is 100% larger than base
auto-aof-rewrite-min-size 64mb   # Minimum size to trigger rewrite
```

**Backup AOF file:**
```bash
# Copy appendonly.aof
cp /var/lib/redis/appendonly.aof /backup/redis/appendonly_$(date +%Y%m%d_%H%M%S).aof
```

**Restore from AOF:**
```bash
# Stop Redis
sudo systemctl stop redis-server

# Replace appendonly.aof
sudo cp /backup/redis/appendonly_20240115.aof /var/lib/redis/appendonly.aof
sudo chown redis:redis /var/lib/redis/appendonly.aof

# Start Redis (will replay AOF)
sudo systemctl start redis-server
```

### Automated Backup Script

```bash
#!/bin/bash
# backup_redis.sh

set -e

# Configuration
REDIS_CLI="redis-cli -a your_password"
BACKUP_DIR="/backups/redis"
RETENTION_DAYS=7

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Trigger background save
$REDIS_CLI BGSAVE

# Wait for save to complete
while [ $($REDIS_CLI LASTSAVE) -eq $($REDIS_CLI LASTSAVE) ]; do
  sleep 1
done

# Copy RDB file
cp /var/lib/redis/dump.rdb "$BACKUP_DIR/dump_$TIMESTAMP.rdb"

# Copy AOF file (if enabled)
if [ -f /var/lib/redis/appendonly.aof ]; then
  cp /var/lib/redis/appendonly.aof "$BACKUP_DIR/appendonly_$TIMESTAMP.aof"
fi

# Remove old backups
find "$BACKUP_DIR" -name "*.rdb" -mtime +$RETENTION_DAYS -delete
find "$BACKUP_DIR" -name "*.aof" -mtime +$RETENTION_DAYS -delete

echo "Backup completed: $TIMESTAMP"
```

**Schedule with cron:**
```bash
# Run every 6 hours
0 */6 * * * /path/to/backup_redis.sh >> /var/log/redis_backup.log 2>&1
```

---

## Replication & High Availability

### Master-Replica Replication

**Master configuration (redis.conf):**
```ini
bind 0.0.0.0
port 6379
requirepass master_password

# Optional: require password from replicas
masterauth replica_password
```

**Replica configuration (redis.conf):**
```ini
bind 0.0.0.0
port 6379
requirepass replica_password

# Replication settings
replicaof master-host 6379
masterauth master_password

# Read-only replica (recommended)
replica-read-only yes

# Replica priority (lower = higher priority for promotion)
replica-priority 100
```

**Check replication status:**
```bash
# On master
redis-cli INFO replication

# On replica
redis-cli INFO replication
```

**Promote replica to master:**
```bash
# On replica
redis-cli REPLICAOF NO ONE
```

### Redis Sentinel (High Availability)

**Sentinel configuration (sentinel.conf):**
```ini
# Sentinel port
port 26379

# Monitor master
sentinel monitor mymaster master-host 6379 2  # 2 = quorum

# Authentication
sentinel auth-pass mymaster master_password

# Failover timeouts
sentinel down-after-milliseconds mymaster 5000
sentinel parallel-syncs mymaster 1
sentinel failover-timeout mymaster 10000

# Notification scripts (optional)
sentinel notification-script mymaster /path/to/notify.sh
sentinel client-reconfig-script mymaster /path/to/reconfig.sh
```

**Start Sentinel:**
```bash
redis-sentinel /etc/redis/sentinel.conf
# Or
redis-server /etc/redis/sentinel.conf --sentinel
```

**Check Sentinel status:**
```bash
redis-cli -p 26379 SENTINEL masters
redis-cli -p 26379 SENTINEL slaves mymaster
redis-cli -p 26379 SENTINEL sentinels mymaster
```

**Manual failover:**
```bash
redis-cli -p 26379 SENTINEL failover mymaster
```

**Connect via Sentinel (application):**
```python
from redis.sentinel import Sentinel

sentinel = Sentinel([
    ('sentinel1', 26379),
    ('sentinel2', 26379),
    ('sentinel3', 26379)
], socket_timeout=0.1)

# Get master
master = sentinel.master_for('mymaster', socket_timeout=0.1, password='master_password')
master.set('key', 'value')

# Get replica (for reads)
replica = sentinel.slave_for('mymaster', socket_timeout=0.1, password='master_password')
value = replica.get('key')
```

### Redis Cluster

**Cluster configuration (redis.conf on each node):**
```ini
port 7000
cluster-enabled yes
cluster-config-file nodes-7000.conf
cluster-node-timeout 5000
appendonly yes
```

**Create cluster:**
```bash
# Start 6 Redis instances (3 masters, 3 replicas)
redis-server /etc/redis/redis-7000.conf
redis-server /etc/redis/redis-7001.conf
redis-server /etc/redis/redis-7002.conf
redis-server /etc/redis/redis-7003.conf
redis-server /etc/redis/redis-7004.conf
redis-server /etc/redis/redis-7005.conf

# Create cluster
redis-cli --cluster create \
  127.0.0.1:7000 127.0.0.1:7001 127.0.0.1:7002 \
  127.0.0.1:7003 127.0.0.1:7004 127.0.0.1:7005 \
  --cluster-replicas 1
```

**Check cluster status:**
```bash
redis-cli -c -p 7000 CLUSTER INFO
redis-cli -c -p 7000 CLUSTER NODES
```

**Add node to cluster:**
```bash
# Add new node
redis-cli --cluster add-node new-node:7006 existing-node:7000

# Reshard data to new node
redis-cli --cluster reshard existing-node:7000
```

**Remove node from cluster:**
```bash
redis-cli --cluster del-node existing-node:7000 <node-id>
```

---

## Performance Tuning

### Configuration Parameters

**Memory settings:**
```ini
# Maximum memory
maxmemory 2gb

# Eviction policy
maxmemory-policy allkeys-lru  # Options:
# - noeviction: Return errors when memory limit reached
# - allkeys-lru: Evict any key using LRU
# - allkeys-lfu: Evict any key using LFU (Redis 4.0+)
# - volatile-lru: Evict keys with TTL using LRU
# - volatile-lfu: Evict keys with TTL using LFU
# - allkeys-random: Evict random keys
# - volatile-random: Evict random keys with TTL
# - volatile-ttl: Evict keys with shortest TTL

# LRU/LFU samples
maxmemory-samples 5
```

**Persistence tuning:**
```ini
# RDB compression
rdbcompression yes
rdbchecksum yes

# AOF rewrite
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb

# AOF fsync
appendfsync everysec  # Balance between performance and durability
no-appendfsync-on-rewrite yes  # Don't fsync during rewrite
```

**Network tuning:**
```ini
# TCP backlog
tcp-backlog 511

# TCP keepalive
tcp-keepalive 300

# Client timeout
timeout 300

# Max clients
maxclients 10000
```

### Monitoring Slow Commands

**Enable slow log:**
```bash
# Set slow log threshold (microseconds)
redis-cli CONFIG SET slowlog-log-slower-than 10000  # 10ms

# Set slow log max entries
redis-cli CONFIG SET slowlog-max-len 128
```

**View slow log:**
```bash
# View slow log
redis-cli SLOWLOG GET 10

# Get slow log length
redis-cli SLOWLOG LEN

# Reset slow log
redis-cli SLOWLOG RESET
```

### Key Analysis

**Find large keys:**
```bash
redis-cli --bigkeys

# Sample keys
redis-cli --bigkeys --i 0.1  # Sample every 0.1 seconds
```

**Memory usage of key:**
```bash
redis-cli MEMORY USAGE mykey
```

**Scan keys (don't use KEYS in production):**
```bash
# Bad: KEYS * (blocks server)
redis-cli KEYS *

# Good: SCAN (iterative, non-blocking)
redis-cli --scan --pattern 'user:*'
```

---

## Monitoring & Alerting

### Key Metrics

**Server info:**
```bash
# All info
redis-cli INFO

# Specific sections
redis-cli INFO server
redis-cli INFO clients
redis-cli INFO memory
redis-cli INFO persistence
redis-cli INFO stats
redis-cli INFO replication
redis-cli INFO cpu
redis-cli INFO keyspace
```

**Memory usage:**
```bash
redis-cli INFO memory | grep used_memory_human
redis-cli INFO memory | grep maxmemory_human
redis-cli INFO memory | grep mem_fragmentation_ratio
```

**Connected clients:**
```bash
redis-cli INFO clients | grep connected_clients
redis-cli CLIENT LIST
```

**Commands per second:**
```bash
redis-cli INFO stats | grep instantaneous_ops_per_sec
```

**Hit rate:**
```bash
redis-cli INFO stats | grep keyspace_hits
redis-cli INFO stats | grep keyspace_misses

# Calculate hit rate:
# hit_rate = keyspace_hits / (keyspace_hits + keyspace_misses)
```

**Replication lag:**
```bash
# On replica
redis-cli INFO replication | grep master_last_io_seconds_ago
```

**Key count:**
```bash
redis-cli DBSIZE
redis-cli INFO keyspace
```

### Monitoring Tools

**redis-cli --stat:** Real-time statistics
```bash
redis-cli --stat
```

**redis-cli --latency:** Latency monitoring
```bash
redis-cli --latency
redis-cli --latency-history
redis-cli --latency-dist
```

**redis-cli --intrinsic-latency:** Measure intrinsic latency
```bash
redis-cli --intrinsic-latency 100  # Run for 100 seconds
```

### Alerting Thresholds

- **Memory usage:** >80% of maxmemory
- **Connected clients:** >80% of maxclients
- **Replication lag:** >10 seconds
- **Hit rate:** <80%
- **Evicted keys:** >1000 per minute
- **Blocked clients:** >0
- **Rejected connections:** >0

---

## Common Operations

### Key Operations

**Set key with expiration:**
```bash
# Set with TTL (seconds)
redis-cli SETEX mykey 3600 "value"

# Set with TTL (milliseconds)
redis-cli PSETEX mykey 3600000 "value"

# Set if not exists
redis-cli SETNX mykey "value"

# Set with expiration if not exists
redis-cli SET mykey "value" EX 3600 NX
```

**Get key TTL:**
```bash
redis-cli TTL mykey  # Seconds
redis-cli PTTL mykey  # Milliseconds
```

**Remove expiration:**
```bash
redis-cli PERSIST mykey
```

**Delete keys:**
```bash
# Delete single key
redis-cli DEL mykey

# Delete multiple keys
redis-cli DEL key1 key2 key3

# Delete keys by pattern (use with caution)
redis-cli --scan --pattern 'temp:*' | xargs redis-cli DEL
```

**Rename key:**
```bash
redis-cli RENAME oldkey newkey
redis-cli RENAMENX oldkey newkey  # Only if newkey doesn't exist
```

### Database Operations

**Select database:**
```bash
redis-cli SELECT 0  # Database 0-15 (default 16 databases)
```

**Flush database:**
```bash
# Flush current database
redis-cli FLUSHDB

# Flush all databases
redis-cli FLUSHALL

# Async flush (non-blocking)
redis-cli FLUSHDB ASYNC
redis-cli FLUSHALL ASYNC
```

**Database size:**
```bash
redis-cli DBSIZE
```

### Data Structures

**Strings:**
```bash
redis-cli SET mykey "value"
redis-cli GET mykey
redis-cli INCR counter
redis-cli INCRBY counter 10
redis-cli DECR counter
```

**Hashes:**
```bash
redis-cli HSET user:1 name "Alice" email "alice@example.com"
redis-cli HGET user:1 name
redis-cli HGETALL user:1
redis-cli HDEL user:1 email
```

**Lists:**
```bash
redis-cli LPUSH mylist "item1" "item2"
redis-cli RPUSH mylist "item3"
redis-cli LRANGE mylist 0 -1
redis-cli LPOP mylist
redis-cli RPOP mylist
```

**Sets:**
```bash
redis-cli SADD myset "member1" "member2"
redis-cli SMEMBERS myset
redis-cli SISMEMBER myset "member1"
redis-cli SREM myset "member1"
```

**Sorted Sets:**
```bash
redis-cli ZADD leaderboard 100 "player1" 200 "player2"
redis-cli ZRANGE leaderboard 0 -1 WITHSCORES
redis-cli ZREVRANGE leaderboard 0 9  # Top 10
redis-cli ZINCRBY leaderboard 10 "player1"
```

---

## Troubleshooting

### Common Issues

**Issue: Connection refused**
```bash
# Check if Redis is running
sudo systemctl status redis-server

# Check listening address
redis-cli CONFIG GET bind
redis-cli CONFIG GET port

# Check logs
sudo tail -f /var/log/redis/redis-server.log
```

**Issue: Out of memory**
```bash
# Check memory usage
redis-cli INFO memory

# Check maxmemory setting
redis-cli CONFIG GET maxmemory

# Increase maxmemory
redis-cli CONFIG SET maxmemory 4gb

# Check eviction policy
redis-cli CONFIG GET maxmemory-policy

# Find large keys
redis-cli --bigkeys

# Delete unused keys
redis-cli DEL unused_key
```

**Issue: High memory fragmentation**
```bash
# Check fragmentation ratio
redis-cli INFO memory | grep mem_fragmentation_ratio

# If ratio > 1.5, consider:
# 1. Restart Redis (will defragment)
# 2. Enable active defragmentation (Redis 4.0+)
redis-cli CONFIG SET activedefrag yes
```

**Issue: Slow performance**
```bash
# Check slow log
redis-cli SLOWLOG GET 10

# Check latency
redis-cli --latency

# Check for blocking commands (KEYS, FLUSHALL, etc.)
redis-cli CLIENT LIST | grep blocked

# Check persistence impact
redis-cli INFO persistence | grep rdb_bgsave_in_progress
redis-cli INFO persistence | grep aof_rewrite_in_progress
```

**Issue: Replication lag**
```bash
# Check replication status
redis-cli INFO replication

# Check network latency
ping master-host

# Check master load
redis-cli -h master-host INFO stats | grep instantaneous_ops_per_sec

# Consider:
# - Increase replica-priority
# - Add more replicas
# - Reduce write load on master
```

**Issue: Connection limit reached**
```bash
# Check connected clients
redis-cli INFO clients | grep connected_clients

# Check max clients
redis-cli CONFIG GET maxclients

# Increase max clients
redis-cli CONFIG SET maxclients 20000

# Find and kill idle clients
redis-cli CLIENT LIST | grep idle
redis-cli CLIENT KILL <addr>
```

---

## Security

### Authentication

**Set password (redis.conf):**
```ini
requirepass your_secure_password
```

**Or dynamically:**
```bash
redis-cli CONFIG SET requirepass your_secure_password
```

**Connect with password:**
```bash
redis-cli -a your_secure_password
# Or
redis-cli
AUTH your_secure_password
```

### ACL (Access Control Lists) - Redis 6.0+

**Create user:**
```bash
# Create user with specific permissions
redis-cli ACL SETUSER alice on >password ~cached:* +get +set

# Explanation:
# on: Enable user
# >password: Set password
# ~cached:*: Allow access to keys matching pattern
# +get +set: Allow GET and SET commands
```

**List users:**
```bash
redis-cli ACL LIST
redis-cli ACL USERS
```

**View user permissions:**
```bash
redis-cli ACL GETUSER alice
```

**Delete user:**
```bash
redis-cli ACL DELUSER alice
```

### SSL/TLS

**Enable TLS (redis.conf):**
```ini
port 0
tls-port 6379
tls-cert-file /path/to/redis.crt
tls-key-file /path/to/redis.key
tls-ca-cert-file /path/to/ca.crt
```

**Connect with TLS:**
```bash
redis-cli --tls --cert /path/to/client.crt --key /path/to/client.key --cacert /path/to/ca.crt
```

### Disable Dangerous Commands

**Rename commands (redis.conf):**
```ini
rename-command FLUSHDB ""
rename-command FLUSHALL ""
rename-command KEYS ""
rename-command CONFIG "CONFIG_abc123"
```

### Network Security

**Bind to specific interface:**
```ini
bind 127.0.0.1 10.0.1.10
```

**Protected mode:**
```ini
protected-mode yes  # Requires password or bind to localhost
```

---

## Upgrade Procedures

### Minor Version Upgrade

**Ubuntu/Debian:**
```bash
# Update package list
sudo apt update

# Upgrade Redis
sudo apt upgrade redis

# Restart
sudo systemctl restart redis-server
```

### Major Version Upgrade

**Upgrade from Redis 5.0 to 6.0:**
```bash
# 1. Backup data
redis-cli BGSAVE
cp /var/lib/redis/dump.rdb /backup/redis/

# 2. Install new version
sudo apt update
sudo apt install redis=6:6.0.0-1

# 3. Update configuration (check for deprecated options)
sudo nano /etc/redis/redis.conf

# 4. Restart Redis
sudo systemctl restart redis-server

# 5. Verify version
redis-cli INFO server | grep redis_version
```

---

## References

- **Official Documentation:** https://redis.io/documentation
- **Commands Reference:** https://redis.io/commands
- **Redis Best Practices:** https://redis.io/topics/admin
- **Redis Persistence:** https://redis.io/topics/persistence
- **Redis Replication:** https://redis.io/topics/replication
- **Redis Sentinel:** https://redis.io/topics/sentinel
- **Redis Cluster:** https://redis.io/topics/cluster-tutorial

---

## Related Documentation

- **Operations Guide:** `docs/guides/persistence_operations_guide__t__.md` - General strategies and concepts
- **Persistence Guide:** `docs/guides/persistence_guide__t__.md` - Choosing storage technologies
- **Cloud Databases Runbook:** `cloud_databases_runbook__t__.md` - AWS ElastiCache, Azure Cache for Redis
