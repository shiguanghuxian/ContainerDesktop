import Foundation

enum DeveloperRunTemplate: String, CaseIterable, Identifiable, Hashable, Sendable {
    case nginx
    case postgres
    case mysql
    case redis
    case mongodb
    case minio
    case rabbitmq
    case neo4j
    case opensearch
    case redpanda

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nginx: "Nginx"
        case .postgres: "PostgreSQL"
        case .mysql: "MySQL"
        case .redis: "Redis"
        case .mongodb: "MongoDB"
        case .minio: "MinIO"
        case .rabbitmq: "RabbitMQ"
        case .neo4j: "Neo4j"
        case .opensearch: "OpenSearch"
        case .redpanda: "Redpanda"
        }
    }

    var systemImage: String {
        switch self {
        case .nginx: "safari"
        case .postgres, .mysql, .mongodb: "cylinder.split.1x2"
        case .redis: "bolt.horizontal.circle"
        case .minio: "externaldrive.connected.to.line.below"
        case .rabbitmq, .redpanda: "arrow.triangle.branch"
        case .neo4j: "point.3.connected.trianglepath.dotted"
        case .opensearch: "magnifyingglass.circle"
        }
    }

    var searchKeywords: [String] {
        switch self {
        case .nginx:
            ["nginx", "web", "http", "website", "服务", "网站"]
        case .postgres:
            ["postgres", "postgresql", "pg", "database", "数据库"]
        case .mysql:
            ["mysql", "mariadb", "database", "数据库"]
        case .redis:
            ["redis", "valkey", "cache", "缓存"]
        case .mongodb:
            ["mongo", "mongodb", "document", "数据库"]
        case .minio:
            ["minio", "s3", "object", "storage", "对象存储"]
        case .rabbitmq:
            ["rabbitmq", "amqp", "mq", "message", "消息"]
        case .neo4j:
            ["neo4j", "graph", "bolt", "图数据库"]
        case .opensearch:
            ["opensearch", "elasticsearch", "search", "检索"]
        case .redpanda:
            ["redpanda", "kafka", "stream", "消息", "流"]
        }
    }

    func summary(language: AppLanguage) -> String {
        let ports = options().ports.joined(separator: ", ")
        if language.resolved == .zhHans {
            return "\(image) · 端口 \(ports.isEmpty ? "无" : ports)"
        }
        return "\(image) · ports \(ports.isEmpty ? "none" : ports)"
    }

    var image: String {
        switch self {
        case .nginx:
            "docker.io/library/nginx:latest"
        case .postgres:
            "docker.io/library/postgres:16"
        case .mysql:
            "docker.io/library/mysql:8"
        case .redis:
            "docker.io/library/redis:7"
        case .mongodb:
            "docker.io/library/mongo:7"
        case .minio:
            "quay.io/minio/minio:latest"
        case .rabbitmq:
            "docker.io/library/rabbitmq:3-management"
        case .neo4j:
            "docker.io/library/neo4j:latest"
        case .opensearch:
            "docker.io/opensearchproject/opensearch:latest"
        case .redpanda:
            "docker.io/redpandadata/redpanda:latest"
        }
    }

    func options(containerName: String? = nil) -> ContainerRunOptions {
        var options = ContainerRunOptions(
            name: containerName,
            image: image,
            detached: true
        )

        switch self {
        case .nginx:
            options.ports = ["8080:80/tcp"]
        case .postgres:
            options.ports = ["5432:5432/tcp"]
            options.env = [
                "POSTGRES_HOST_AUTH_METHOD=trust",
            ]
            options.volumes = ["cd-postgres-data:/var/lib/postgresql/data"]
        case .mysql:
            options.ports = ["3306:3306/tcp"]
            options.env = [
                "MYSQL_ALLOW_EMPTY_PASSWORD=yes",
            ]
            options.volumes = ["cd-mysql-data:/var/lib/mysql"]
        case .redis:
            options.ports = ["6379:6379/tcp"]
            options.volumes = ["cd-redis-data:/data"]
        case .mongodb:
            options.ports = ["27017:27017/tcp"]
            options.volumes = ["cd-mongodb-data:/data/db"]
        case .minio:
            options.ports = ["9000:9000/tcp", "9001:9001/tcp"]
            options.env = [
                "MINIO_ROOT_USER=minioadmin",
                "MINIO_ROOT_PASSWORD=<change-me>",
            ]
            options.volumes = ["cd-minio-data:/data"]
            options.command = ["server", "/data", "--console-address", ":9001"]
        case .rabbitmq:
            options.ports = ["5672:5672/tcp", "15672:15672/tcp"]
            options.volumes = ["cd-rabbitmq-data:/var/lib/rabbitmq"]
        case .neo4j:
            options.ports = ["7474:7474/tcp", "7687:7687/tcp"]
            options.env = ["NEO4J_AUTH=none"]
            options.volumes = ["cd-neo4j-data:/data"]
        case .opensearch:
            options.ports = ["9200:9200/tcp", "9600:9600/tcp"]
            options.env = [
                "discovery.type=single-node",
                "plugins.security.disabled=true",
                "OPENSEARCH_INITIAL_ADMIN_PASSWORD=<change-me>",
            ]
            options.volumes = ["cd-opensearch-data:/usr/share/opensearch/data"]
        case .redpanda:
            options.ports = ["9092:9092/tcp", "9644:9644/tcp"]
            options.command = [
                "redpanda",
                "start",
                "--overprovisioned",
                "--smp",
                "1",
                "--memory",
                "512M",
                "--reserve-memory",
                "0M",
                "--node-id",
                "0",
                "--check=false",
                "--kafka-addr",
                "0.0.0.0:9092",
                "--advertise-kafka-addr",
                "127.0.0.1:9092",
            ]
            options.volumes = ["cd-redpanda-data:/var/lib/redpanda/data"]
        }

        return options
    }

    func commandPreview(containerName: String? = nil) -> String {
        AppOperationCommandPreview.make(executable: "container", arguments: options(containerName: containerName).arguments)
    }

    static func template(id: ID) -> DeveloperRunTemplate? {
        allCases.first { $0.id == id }
    }
}
