# MongoDB Operations Runbook

## Overview

MongoDB is a document-oriented NoSQL database known for its flexibility, scalability, and developer-friendly API. This runbook provides specific commands and procedures for production MongoDB operations.

**Key capabilities:**
- Document model (JSON/BSON)
- Flexible schema
- Horizontal scaling (sharding)
- High availability (replica sets)
- Rich query language
- Aggregation framework
- Change streams
- Transactions (4.0+)

**Versions covered:** MongoDB 5.0+

---

## Installation & Setup

### Installation

**Ubuntu/Debian:**
```bash
# Import MongoDB public GPG key
wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | sudo apt-key add -

# Create list file
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/6.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list

# Install MongoDB
sudo apt update
sudo apt install -y mongodb-org

# Start service
sudo systemctl start mongod
sudo systemctl enable mongod
```

**RHEL/CentOS:**
```bash
# Create repository file
sudo tee /etc/yum.repos.d/mongodb-org-6.0.repo <<EOF
[mongodb-org-6.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/\$releasever/mongodb-org/6.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-6.0.asc
EOF

# Install MongoDB
sudo yum install -y mongodb-org

# Start service
sudo systemctl start mongod
sudo systemctl enable mongod
```

**macOS:**
```bash
# Using Homebrew
brew tap mongodb/brew
brew install mongodb-community@6.0

# Start service
brew services start mongodb-community@6.0
```

### Initial Configuration

**Connect to MongoDB:**
```bash
mongosh
# Or for older versions:
# mongo
```

**Create database and user:**
```javascript
// Switch to database (creates if doesn't exist)
use myapp

// Create user
db.createUser({
  user: "myapp_user",
  pwd: "secure_password",
  roles: [
    { role: "readWrite", db: "myapp" }
  ]
})

// Create admin user
use admin
db.createUser({
  user: "admin",
  pwd: "admin_password",
  roles: [
    { role: "userAdminAnyDatabase", db: "admin" },
    { role: "readWriteAnyDatabase", db: "admin" },
    { role: "dbAdminAnyDatabase", db: "admin" },
    { role: "clusterAdmin", db: "admin" }
  ]
})
```

**Enable authentication (/etc/mongod.conf):**
```yaml
security:
  authorization: enabled

net:
  port: 27017
  bindIp: 0.0.0.0  # Or specific IP

storage:
  dbPath: /var/lib/mongodb
  journal:
    enabled: true

systemLog:
  destination: file
  path: /var/log/mongodb/mongod.log
  logAppend: true

processManagement:
  fork: true
  pidFilePath: /var/run/mongodb/mongod.pid
```

**Restart MongoDB:**
```bash
sudo systemctl restart mongod
```

**Connect with authentication:**
```bash
mongosh -u myapp_user -p secure_password --authenticationDatabase myapp myapp
```

---

## Backup & Recovery

### Logical Backup (mongodump)

**Backup single database:**
```bash
# Basic backup
mongodump --uri="mongodb://localhost:27017/myapp" --out=/backup/dir

# With authentication
mongodump --uri="mongodb://myapp_user:password@localhost:27017/myapp" --out=/backup/dir

# Specific collection
mongodump --uri="mongodb://localhost:27017/myapp" --collection=users --out=/backup/dir

# With compression
mongodump --uri="mongodb://localhost:27017/myapp" --gzip --out=/backup/dir
```

**Backup all databases:**
```bash
mongodump --uri="mongodb://admin:password@localhost:27017" --out=/backup/dir
```

**Restore from backup:**
```bash
# Restore database
mongorestore --uri="mongodb://localhost:27017/myapp" /backup/dir/myapp

# Restore specific collection
mongorestore --uri="mongodb://localhost:27017/myapp" --collection=users /backup/dir/myapp/users.bson

# Restore with drop (replace existing data)
mongorestore --uri="mongodb://localhost:27017/myapp" --drop /backup/dir/myapp

# Restore from compressed backup
mongorestore --uri="mongodb://localhost:27017/myapp" --gzip /backup/dir/myapp
```

### Point-in-Time Backup (Oplog)

**Enable oplog (replica set required):**

Oplog is automatically enabled for replica sets.

**Backup with oplog:**
```bash
# Backup with oplog for point-in-time recovery
mongodump --uri="mongodb://localhost:27017" --oplog --out=/backup/dir
```

**Restore to specific point in time:**
```bash
# 1. Restore full backup
mongorestore --uri="mongodb://localhost:27017" /backup/dir

# 2. Replay oplog to specific timestamp
mongorestore --uri="mongodb://localhost:27017" --oplogReplay --oplogLimit=1642262400:1 /backup/dir/oplog.bson
```

### Filesystem Snapshot

**For cloud providers (AWS EBS, GCP Persistent Disk):**
```bash
# 1. Flush and lock database
mongosh --eval "db.fsyncLock()"

# 2. Create snapshot (cloud provider specific)
aws ec2 create-snapshot --volume-id vol-xxxxx --description "MongoDB backup"

# 3. Unlock database
mongosh --eval "db.fsyncUnlock()"
```

### Automated Backup Script

```bash
#!/bin/bash
# backup_mongodb.sh

set -e

# Configuration
MONGO_URI="mongodb://admin:password@localhost:27017"
BACKUP_DIR="/backups/mongodb"
RETENTION_DAYS=7

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Backup all databases
mongodump --uri="$MONGO_URI" --gzip --out="$BACKUP_DIR/$TIMESTAMP"

# Remove old backups
find "$BACKUP_DIR" -type d -mtime +$RETENTION_DAYS -exec rm -rf {} +

echo "Backup completed: $TIMESTAMP"
```

**Schedule with cron:**
```bash
# Run daily at 2 AM
0 2 * * * /path/to/backup_mongodb.sh >> /var/log/mongodb_backup.log 2>&1
```

---

## Replication & High Availability

### Replica Set Setup

**Configure replica set (mongod.conf on all nodes):**
```yaml
replication:
  replSetName: "rs0"

net:
  bindIp: 0.0.0.0
  port: 27017
```

**Restart MongoDB on all nodes:**
```bash
sudo systemctl restart mongod
```

**Initialize replica set (on primary node):**
```javascript
// Connect to MongoDB
mongosh

// Initialize replica set
rs.initiate({
  _id: "rs0",
  members: [
    { _id: 0, host: "node1:27017" },
    { _id: 1, host: "node2:27017" },
    { _id: 2, host: "node3:27017" }
  ]
})

// Check status
rs.status()
```

**Add member to replica set:**
```javascript
rs.add("node4:27017")

// Add as arbiter (voting only, no data)
rs.addArb("arbiter:27017")
```

**Remove member:**
```javascript
rs.remove("node4:27017")
```

**Check replica set status:**
```javascript
rs.status()
rs.conf()
rs.isMaster()
```

**Read preference:**
```javascript
// Read from primary only (default)
db.users.find().readPref("primary")

// Read from secondary
db.users.find().readPref("secondary")

// Read from primary preferred
db.users.find().readPref("primaryPreferred")

// Read from secondary preferred
db.users.find().readPref("secondaryPreferred")

// Read from nearest
db.users.find().readPref("nearest")
```

### Sharding

**Start config servers (3 nodes):**
```bash
# mongod.conf
sharding:
  clusterRole: configsvr

replication:
  replSetName: "configReplSet"

# Start mongod
mongod --configsvr --replSet configReplSet --port 27019 --dbpath /data/configdb
```

**Initialize config server replica set:**
```javascript
rs.initiate({
  _id: "configReplSet",
  configsvr: true,
  members: [
    { _id: 0, host: "config1:27019" },
    { _id: 1, host: "config2:27019" },
    { _id: 2, host: "config3:27019" }
  ]
})
```

**Start shard servers (replica sets):**
```bash
# mongod.conf
sharding:
  clusterRole: shardsvr

replication:
  replSetName: "shard1"

# Start mongod
mongod --shardsvr --replSet shard1 --port 27018 --dbpath /data/shard1
```

**Start mongos (query router):**
```bash
mongos --configdb configReplSet/config1:27019,config2:27019,config3:27019 --port 27017
```

**Add shards:**
```javascript
// Connect to mongos
mongosh --port 27017

// Add shards
sh.addShard("shard1/shard1-node1:27018,shard1-node2:27018,shard1-node3:27018")
sh.addShard("shard2/shard2-node1:27018,shard2-node2:27018,shard2-node3:27018")

// Check status
sh.status()
```

**Enable sharding on database:**
```javascript
sh.enableSharding("myapp")
```

**Shard collection:**
```javascript
// Create index on shard key
db.users.createIndex({ user_id: 1 })

// Shard collection
sh.shardCollection("myapp.users", { user_id: 1 })

// Or with hashed shard key
sh.shardCollection("myapp.users", { user_id: "hashed" })
```

### Failover Procedures

**Automatic failover:**

MongoDB replica sets automatically elect a new primary if the current primary fails (typically within 10-30 seconds).

**Manual failover (step down primary):**
```javascript
// Step down primary (triggers election)
rs.stepDown(60)  // Step down for 60 seconds

// Force step down
rs.stepDown(60, true)
```

**Check replication lag:**
```javascript
rs.printReplicationInfo()
rs.printSecondaryReplicationInfo()
```

---

## Performance Tuning

### Configuration Parameters

**WiredTiger cache (mongod.conf):**
```yaml
storage:
  wiredTiger:
    engineConfig:
      cacheSizeGB: 12  # 50% of RAM minus 1-2GB
```

**Connection pool:**
```yaml
net:
  maxIncomingConnections: 1000
```

### Identifying Slow Queries

**Enable profiling:**
```javascript
// Profile all queries
db.setProfilingLevel(2)

// Profile slow queries (>100ms)
db.setProfilingLevel(1, { slowms: 100 })

// Disable profiling
db.setProfilingLevel(0)

// Check profiling status
db.getProfilingStatus()
```

**View slow queries:**
```javascript
// View profiled queries
db.system.profile.find().sort({ ts: -1 }).limit(10).pretty()

// Find queries slower than 1000ms
db.system.profile.find({ millis: { $gt: 1000 } }).sort({ millis: -1 }).pretty()
```

**Use explain:**
```javascript
// Explain query execution
db.users.find({ email: "alice@example.com" }).explain("executionStats")

// Look for:
// - totalDocsExamined vs nReturned (should be close)
// - executionTimeMillis (should be low)
// - stage: "COLLSCAN" (bad, full collection scan)
// - stage: "IXSCAN" (good, index scan)
```

### Indexing

**Create indexes:**
```javascript
// Single field index
db.users.createIndex({ email: 1 })

// Compound index
db.orders.createIndex({ user_id: 1, created_at: -1 })

// Unique index
db.users.createIndex({ email: 1 }, { unique: true })

// Sparse index (only index documents with field)
db.users.createIndex({ phone: 1 }, { sparse: true })

// TTL index (auto-delete after expiration)
db.sessions.createIndex({ created_at: 1 }, { expireAfterSeconds: 3600 })

// Text index (full-text search)
db.posts.createIndex({ content: "text" })

// Geospatial index
db.locations.createIndex({ coordinates: "2dsphere" })

// Partial index
db.users.createIndex(
  { email: 1 },
  { partialFilterExpression: { active: true } }
)
```

**Check index usage:**
```javascript
// List indexes
db.users.getIndexes()

// Index statistics
db.users.aggregate([{ $indexStats: {} }])

// Find unused indexes
db.users.aggregate([
  { $indexStats: {} },
  { $match: { "accesses.ops": 0 } }
])
```

**Drop index:**
```javascript
db.users.dropIndex("email_1")
db.users.dropIndexes()  // Drop all indexes except _id
```

### Query Optimization

**Use projection:**
```javascript
// Bad: Return all fields
db.users.find({ email: "alice@example.com" })

// Good: Return only needed fields
db.users.find({ email: "alice@example.com" }, { name: 1, email: 1 })
```

**Use covered queries:**
```javascript
// Create covering index
db.users.createIndex({ email: 1, name: 1 })

// Query covered by index (no document fetch)
db.users.find({ email: "alice@example.com" }, { _id: 0, email: 1, name: 1 })
```

**Avoid large result sets:**
```javascript
// Use limit
db.users.find().limit(100)

// Use pagination
db.users.find().skip(100).limit(100)

// Better pagination with range queries
db.users.find({ _id: { $gt: lastId } }).limit(100)
```

---

## Monitoring & Alerting

### Key Metrics

**Database statistics:**
```javascript
// Database stats
db.stats()

// Collection stats
db.users.stats()

// Server status
db.serverStatus()
```

**Connection count:**
```javascript
db.serverStatus().connections

// Current operations
db.currentOp()

// Kill operation
db.killOp(opid)
```

**Replication lag:**
```javascript
rs.printReplicationInfo()
rs.printSecondaryReplicationInfo()
```

**Disk usage:**
```javascript
db.stats().dataSize
db.stats().storageSize
db.stats().indexSize
```

**Cache statistics:**
```javascript
db.serverStatus().wiredTiger.cache
```

### Monitoring Tools

**MongoDB Compass:** GUI tool for monitoring and querying

**mongostat:** Real-time statistics
```bash
mongostat --uri="mongodb://localhost:27017" --discover
```

**mongotop:** Track read/write activity
```bash
mongotop --uri="mongodb://localhost:27017" 5  # Update every 5 seconds
```

### Alerting Thresholds

- **Connection count:** >80% of maxIncomingConnections
- **Replication lag:** >60 seconds
- **Cache hit ratio:** <95%
- **Disk space:** >80% full
- **Long-running queries:** >5 seconds
- **Oplog window:** <24 hours

---

## Common Operations

### User Management

**Create user:**
```javascript
use myapp
db.createUser({
  user: "alice",
  pwd: "secure_password",
  roles: [
    { role: "read", db: "myapp" }
  ]
})
```

**Grant roles:**
```javascript
db.grantRolesToUser("alice", [
  { role: "readWrite", db: "myapp" }
])
```

**Revoke roles:**
```javascript
db.revokeRolesFromUser("alice", [
  { role: "readWrite", db: "myapp" }
])
```

**Change password:**
```javascript
db.changeUserPassword("alice", "new_password")
```

**Drop user:**
```javascript
db.dropUser("alice")
```

**View users:**
```javascript
db.getUsers()
show users
```

### Database Maintenance

**Compact collection:**
```javascript
db.runCommand({ compact: "users" })
```

**Validate collection:**
```javascript
db.users.validate({ full: true })
```

**Repair database:**
```bash
# Stop mongod
sudo systemctl stop mongod

# Run repair
mongod --repair --dbpath /var/lib/mongodb

# Start mongod
sudo systemctl start mongod
```

---

## Troubleshooting

### Common Issues

**Issue: Connection refused**
```bash
# Check if MongoDB is running
sudo systemctl status mongod

# Check listening address
mongosh --eval "db.serverCmdLineOpts()"

# Check logs
sudo tail -f /var/log/mongodb/mongod.log
```

**Issue: Out of disk space**
```javascript
// Check database sizes
db.adminCommand({ listDatabases: 1 })

// Check collection sizes
db.stats()

// Compact collections
db.runCommand({ compact: "users" })

// Drop unused databases/collections
db.dropDatabase()
db.collection.drop()
```

**Issue: High memory usage**
```javascript
// Check WiredTiger cache
db.serverStatus().wiredTiger.cache

// Reduce cache size (mongod.conf)
storage:
  wiredTiger:
    engineConfig:
      cacheSizeGB: 8
```

**Issue: Replication lag**
```javascript
// Check replication status
rs.status()
rs.printSecondaryReplicationInfo()

// Check oplog size
rs.printReplicationInfo()

// Increase oplog size
db.adminCommand({ replSetResizeOplog: 1, size: 16384 })  // 16GB
```

**Issue: Lock contention**
```javascript
// Check current operations
db.currentOp({ $or: [{ waitingForLock: true }, { lockStats: { $exists: true } }] })

// Kill long-running operation
db.killOp(opid)
```

---

## Security

### Authentication

**Enable authentication (mongod.conf):**
```yaml
security:
  authorization: enabled
```

**Create admin user:**
```javascript
use admin
db.createUser({
  user: "admin",
  pwd: "admin_password",
  roles: [ "root" ]
})
```

### SSL/TLS

**Generate certificates:**
```bash
# Generate CA
openssl genrsa -out ca-key.pem 4096
openssl req -new -x509 -days 3650 -key ca-key.pem -out ca.pem

# Generate server certificate
openssl genrsa -out server-key.pem 4096
openssl req -new -key server-key.pem -out server.csr
openssl x509 -req -in server.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out server-cert.pem -days 3650

# Combine key and certificate
cat server-key.pem server-cert.pem > server.pem
```

**Enable SSL (mongod.conf):**
```yaml
net:
  tls:
    mode: requireTLS
    certificateKeyFile: /etc/mongodb/ssl/server.pem
    CAFile: /etc/mongodb/ssl/ca.pem
```

**Connect with SSL:**
```bash
mongosh --tls --tlsCAFile /etc/mongodb/ssl/ca.pem --host localhost
```

### Encryption at Rest

**Enable encryption (mongod.conf):**
```yaml
security:
  enableEncryption: true
  encryptionKeyFile: /etc/mongodb/encryption-key
```

**Generate encryption key:**
```bash
openssl rand -base64 32 > /etc/mongodb/encryption-key
chmod 600 /etc/mongodb/encryption-key
chown mongodb:mongodb /etc/mongodb/encryption-key
```

### Audit Logging

**Enable auditing (MongoDB Enterprise):**
```yaml
auditLog:
  destination: file
  format: JSON
  path: /var/log/mongodb/audit.json
  filter: '{ atype: { $in: [ "authenticate", "createCollection", "dropCollection" ] } }'
```

---

## Upgrade Procedures

### Minor Version Upgrade

**Ubuntu/Debian:**
```bash
# Update package list
sudo apt update

# Upgrade MongoDB
sudo apt upgrade mongodb-org

# Restart
sudo systemctl restart mongod
```

### Major Version Upgrade

**Upgrade from MongoDB 5.0 to 6.0:**
```bash
# 1. Backup all databases
mongodump --uri="mongodb://localhost:27017" --out=/backup/before_upgrade

# 2. Check feature compatibility version
mongosh --eval "db.adminCommand({ getParameter: 1, featureCompatibilityVersion: 1 })"

# 3. Set feature compatibility to current version
mongosh --eval 'db.adminCommand({ setFeatureCompatibilityVersion: "5.0" })'

# 4. Upgrade MongoDB packages
sudo apt update
sudo apt install mongodb-org=6.0.0 mongodb-org-server=6.0.0

# 5. Restart MongoDB
sudo systemctl restart mongod

# 6. Set feature compatibility to new version
mongosh --eval 'db.adminCommand({ setFeatureCompatibilityVersion: "6.0" })'

# 7. Verify version
mongosh --eval "db.version()"
```

---

## References

- **Official Documentation:** https://docs.mongodb.com/
- **Performance Best Practices:** https://docs.mongodb.com/manual/administration/analyzing-mongodb-performance/
- **Replication:** https://docs.mongodb.com/manual/replication/
- **Sharding:** https://docs.mongodb.com/manual/sharding/
- **MongoDB University:** https://university.mongodb.com/

---

## Related Documentation

- **Operations Guide:** `docs/guides/persistence_operations_guide__t__.md` - General strategies and concepts
- **Persistence Guide:** `docs/guides/persistence_guide__t__.md` - Choosing storage technologies
- **Cloud Databases Runbook:** `cloud_databases_runbook__t__.md` - MongoDB Atlas
