import Foundation

enum ContainerPortQuickActionKind: String, Codable, Hashable, Sendable {
    case openURL
    case copyURL
    case copyAddress
    case copyConnectionString
    case copyEnvironmentSnippet
    case copyCLICommand
    case copyHealthCheckCommand

    var menuOrder: Int {
        switch self {
        case .openURL: 0
        case .copyURL: 1
        case .copyAddress: 2
        case .copyConnectionString: 3
        case .copyEnvironmentSnippet: 4
        case .copyCLICommand: 5
        case .copyHealthCheckCommand: 6
        }
    }
}

struct ContainerPortEndpoint: Hashable, Sendable {
    var host: String
    var port: Int
    var source: ContainerBrowserPortTargetSource
    var hostPort: Int?
    var containerPort: Int
    var protocolName: String

    var address: String {
        "\(authorityHost):\(port)"
    }

    private var authorityHost: String {
        host.contains(":") && !host.hasPrefix("[") ? "[\(host)]" : host
    }
}

enum ContainerPortQuickActionCatalog {
    static func targets(
        imageName: String,
        containerPort: Int,
        protocolName: String,
        endpoint: ContainerPortEndpoint
    ) -> [ContainerBrowserPortTarget] {
        guard protocolName == "tcp" else { return [] }
        return templates(imageName: imageName, containerPort: containerPort)
            .compactMap { $0.target(endpoint: endpoint) }
    }

    private static func templates(imageName: String, containerPort: Int) -> [ContainerPortQuickActionTemplate] {
        let image = normalizedImageName(imageName)

        if imageMatches(image, ["clickhouse"]) {
            if containerPort == 8123 {
                return httpService("ClickHouse HTTP")
            }
            if containerPort == 9000 {
                return clickHouseNativeService()
            }
        }

        if imageMatches(image, ["minio"]) {
            if containerPort == 9001 {
                return httpService("MinIO Console")
            }
            if containerPort == 9000 {
                return httpService("MinIO API") + [
                    .copyEnvironmentSnippet("MinIO") { endpoint in
                        guard let url = makeURL(scheme: "http", endpoint: endpoint) else { return nil }
                        return "MINIO_ENDPOINT=\(url)"
                    },
                    .copyCLICommand("MinIO") { endpoint in
                        guard let url = makeURL(scheme: "http", endpoint: endpoint) else { return nil }
                        return "mc alias set local \(shellArgument(url)) '<access-key>' '<secret-key>'"
                    },
                ]
            }
        }

        if imageMatches(image, ["rabbitmq"]) {
            if containerPort == 15672 {
                return httpService("RabbitMQ Management")
            }
            if containerPort == 5671 {
                return uriService(name: "RabbitMQ TLS", scheme: "amqps", userInfo: "guest", envName: "AMQP_URL")
            }
            if containerPort == 5672 {
                return uriService(name: "RabbitMQ", scheme: "amqp", userInfo: "guest", envName: "AMQP_URL")
            }
        }

        if imageMatches(image, ["neo4j"]) {
            if containerPort == 7473 {
                return httpService("Neo4j Browser", scheme: "https")
            }
            if containerPort == 7474 {
                return httpService("Neo4j Browser")
            }
            if containerPort == 7687 {
                return uriService(name: "Neo4j Bolt", scheme: "bolt", envName: "NEO4J_URI") + [
                    .copyCLICommand("Neo4j Bolt") { endpoint in
                        let uri = makeURI(scheme: "bolt", endpoint: endpoint)
                        return "cypher-shell -a \(ShellEscaper.singleQuoted(uri))"
                    },
                ]
            }
        }

        if imageMatches(image, ["emqx"]) {
            if containerPort == 18083 {
                return httpService("EMQX Dashboard")
            }
            if containerPort == 1883 {
                return mqttService(name: "MQTT", scheme: "mqtt")
            }
            if containerPort == 8883 {
                return mqttService(name: "MQTT TLS", scheme: "mqtts")
            }
        }

        if imageMatches(image, ["nats"]) {
            if containerPort == 8222 {
                return httpService("NATS Monitoring")
            }
            if containerPort == 4222 {
                return uriService(name: "NATS", scheme: "nats", envName: "NATS_URL") + [
                    .copyCLICommand("NATS") { endpoint in
                        let uri = makeURI(scheme: "nats", endpoint: endpoint)
                        return "nats --server \(ShellEscaper.singleQuoted(uri)) server info"
                    },
                ]
            }
        }

        if let connection = connectionTemplates(image: image, containerPort: containerPort) {
            return connection
        }

        if let http = httpAPITemplates(image: image, containerPort: containerPort) {
            return http
        }

        if let webService = webServiceName(image: image, containerPort: containerPort) {
            return httpService(webService, scheme: httpsPorts.contains(containerPort) ? "https" : "http")
        }

        if likelyWebPorts.contains(containerPort) {
            return httpService("Web", scheme: httpsPorts.contains(containerPort) ? "https" : "http")
        }

        return [.copyAddress("TCP"), .tcpHealthCheck("TCP")]
    }

    private static func connectionTemplates(image: String, containerPort: Int) -> [ContainerPortQuickActionTemplate]? {
        if servicePortMatches(image: image, tokens: ["postgres", "postgis", "timescale"], port: containerPort, defaultPorts: [5432]) {
            return postgresService()
        }
        if servicePortMatches(image: image, tokens: ["mysql", "mariadb", "percona"], port: containerPort, defaultPorts: [3306]) {
            return mysqlService()
        }
        if servicePortMatches(image: image, tokens: ["mongo"], port: containerPort, defaultPorts: [27017]) {
            return mongoService()
        }
        if servicePortMatches(image: image, tokens: ["redis", "valkey"], port: containerPort, defaultPorts: [6379]) {
            return redisService()
        }
        if servicePortMatches(image: image, tokens: ["memcached"], port: containerPort, defaultPorts: [11211]) {
            return [.copyAddress("Memcached"), .copyEnvironmentSnippet("Memcached") { "MEMCACHED_HOST=\($0.host)\nMEMCACHED_PORT=\($0.port)" }, .tcpHealthCheck("Memcached")]
        }
        if servicePortMatches(image: image, tokens: ["mssql", "sqlserver", "sql-server"], port: containerPort, defaultPorts: [1433]) {
            return uriService(name: "SQL Server", scheme: "sqlserver", envName: "SQLSERVER_URL") + [
                .copyCLICommand("SQL Server") { endpoint in
                    "sqlcmd -S \(endpoint.address) -U sa -P '<password>'"
                },
            ]
        }
        if servicePortMatches(image: image, tokens: ["cassandra"], port: containerPort, defaultPorts: [9042]) {
            return [.copyAddress("Cassandra"), .copyEnvironmentSnippet("Cassandra") { "CASSANDRA_HOST=\($0.host)\nCASSANDRA_PORT=\($0.port)" }, .copyCLICommand("Cassandra") { "cqlsh \(shellArgument($0.host)) \($0.port)" }, .tcpHealthCheck("Cassandra")]
        }
        if servicePortMatches(image: image, tokens: ["kafka", "redpanda"], port: containerPort, defaultPorts: [9092, 19092]) {
            return [.copyAddress("Kafka"), .copyEnvironmentSnippet("Kafka") { "KAFKA_BOOTSTRAP_SERVERS=\($0.address)" }, .copyCLICommand("Kafka") { "kcat -b \(shellArgument($0.address)) -L" }, .tcpHealthCheck("Kafka")]
        }
        if servicePortMatches(image: image, tokens: ["zookeeper", "zoo-keeper"], port: containerPort, defaultPorts: [2181]) {
            return [.copyAddress("ZooKeeper"), .copyEnvironmentSnippet("ZooKeeper") { "ZOOKEEPER_CONNECT=\($0.address)" }, .tcpHealthCheck("ZooKeeper")]
        }
        if servicePortMatches(image: image, tokens: ["etcd"], port: containerPort, defaultPorts: [2379, 2380]) {
            return httpService("etcd") + [.copyEnvironmentSnippet("etcd") { endpoint in
                guard let url = makeURL(scheme: "http", endpoint: endpoint) else { return nil }
                return "ETCDCTL_ENDPOINTS=\(url)"
            }]
        }
        if servicePortMatches(image: image, tokens: ["mosquitto", "mqtt"], port: containerPort, defaultPorts: [1883]) {
            return mqttService(name: "MQTT", scheme: "mqtt")
        }
        if servicePortMatches(image: image, tokens: ["mosquitto", "mqtt"], port: containerPort, defaultPorts: [8883]) {
            return mqttService(name: "MQTT TLS", scheme: "mqtts")
        }
        return nil
    }

    private static func httpAPITemplates(image: String, containerPort: Int) -> [ContainerPortQuickActionTemplate]? {
        if servicePortMatches(image: image, tokens: ["elasticsearch", "opensearch"], port: containerPort, defaultPorts: [9200]) {
            return httpAPIService("Search HTTP", envName: image.contains("opensearch") ? "OPENSEARCH_URL" : "ELASTICSEARCH_URL")
        }
        if servicePortMatches(image: image, tokens: ["influxdb"], port: containerPort, defaultPorts: [8086]) {
            return httpAPIService("InfluxDB", envName: "INFLUX_URL")
        }
        if servicePortMatches(image: image, tokens: ["couchdb"], port: containerPort, defaultPorts: [5984]) {
            return httpAPIService("CouchDB", envName: "COUCHDB_URL")
        }
        if servicePortMatches(image: image, tokens: ["meilisearch"], port: containerPort, defaultPorts: [7700]) {
            return httpAPIService("Meilisearch", envName: "MEILISEARCH_URL")
        }
        if servicePortMatches(image: image, tokens: ["typesense"], port: containerPort, defaultPorts: [8108]) {
            return httpAPIService("Typesense", envName: "TYPESENSE_URL")
        }
        if servicePortMatches(image: image, tokens: ["vault"], port: containerPort, defaultPorts: [8200]) {
            return httpAPIService("Vault", envName: "VAULT_ADDR")
        }
        if servicePortMatches(image: image, tokens: ["consul"], port: containerPort, defaultPorts: [8500]) {
            return httpAPIService("Consul", envName: "CONSUL_HTTP_ADDR")
        }
        return nil
    }

    private static func postgresService() -> [ContainerPortQuickActionTemplate] {
        [
            .copyAddress("PostgreSQL"),
            .copyURI("PostgreSQL", scheme: "postgresql", userInfo: "postgres", path: "postgres"),
            .copyEnvironmentSnippet("PostgreSQL") { endpoint in
                let uri = makeURI(scheme: "postgresql", endpoint: endpoint, userInfo: "postgres", path: "postgres")
                return """
                PGHOST=\(endpoint.host)
                PGPORT=\(endpoint.port)
                PGUSER=postgres
                PGDATABASE=postgres
                DATABASE_URL=\(uri)
                """
            },
            .copyCLICommand("PostgreSQL") { endpoint in
                let uri = makeURI(scheme: "postgresql", endpoint: endpoint, userInfo: "postgres", path: "postgres")
                return "psql \(ShellEscaper.singleQuoted(uri))"
            },
            .copyHealthCheckCommand("PostgreSQL") { endpoint in
                "pg_isready -h \(shellArgument(endpoint.host)) -p \(endpoint.port) -U postgres"
            },
        ]
    }

    private static func mysqlService() -> [ContainerPortQuickActionTemplate] {
        [
            .copyAddress("MySQL"),
            .copyURI("MySQL", scheme: "mysql", userInfo: "root"),
            .copyEnvironmentSnippet("MySQL") { endpoint in
                let uri = makeURI(scheme: "mysql", endpoint: endpoint, userInfo: "root")
                return """
                MYSQL_HOST=\(endpoint.host)
                MYSQL_TCP_PORT=\(endpoint.port)
                MYSQL_USER=root
                DATABASE_URL=\(uri)
                """
            },
            .copyCLICommand("MySQL") { endpoint in
                "mysql -h \(shellArgument(endpoint.host)) -P \(endpoint.port) -u root -p"
            },
            .copyHealthCheckCommand("MySQL") { endpoint in
                "mysqladmin ping -h \(shellArgument(endpoint.host)) -P \(endpoint.port) -u root -p"
            },
        ]
    }

    private static func redisService() -> [ContainerPortQuickActionTemplate] {
        [
            .copyAddress("Redis"),
            .copyURI("Redis", scheme: "redis"),
            .copyEnvironmentSnippet("Redis") { endpoint in
                let uri = makeURI(scheme: "redis", endpoint: endpoint)
                return "REDIS_URL=\(uri)"
            },
            .copyCLICommand("Redis") { endpoint in
                let uri = makeURI(scheme: "redis", endpoint: endpoint)
                return "redis-cli -u \(ShellEscaper.singleQuoted(uri))"
            },
            .copyHealthCheckCommand("Redis") { endpoint in
                let uri = makeURI(scheme: "redis", endpoint: endpoint)
                return "redis-cli -u \(ShellEscaper.singleQuoted(uri)) ping"
            },
        ]
    }

    private static func mongoService() -> [ContainerPortQuickActionTemplate] {
        [
            .copyAddress("MongoDB"),
            .copyURI("MongoDB", scheme: "mongodb"),
            .copyEnvironmentSnippet("MongoDB") { endpoint in
                let uri = makeURI(scheme: "mongodb", endpoint: endpoint)
                return "MONGODB_URI=\(uri)"
            },
            .copyCLICommand("MongoDB") { endpoint in
                let uri = makeURI(scheme: "mongodb", endpoint: endpoint)
                return "mongosh \(ShellEscaper.singleQuoted(uri))"
            },
            .copyHealthCheckCommand("MongoDB") { endpoint in
                let uri = makeURI(scheme: "mongodb", endpoint: endpoint)
                return "mongosh \(ShellEscaper.singleQuoted(uri)) --eval 'db.runCommand({ ping: 1 })'"
            },
        ]
    }

    private static func clickHouseNativeService() -> [ContainerPortQuickActionTemplate] {
        uriService(name: "ClickHouse", scheme: "clickhouse", envName: "CLICKHOUSE_URL") + [
            .copyCLICommand("ClickHouse") { endpoint in
                "clickhouse-client --host \(shellArgument(endpoint.host)) --port \(endpoint.port)"
            },
        ]
    }

    private static func mqttService(name: String, scheme: String) -> [ContainerPortQuickActionTemplate] {
        uriService(name: name, scheme: scheme, envName: "MQTT_URL") + [
            .copyCLICommand(name) { endpoint in
                "mosquitto_sub -h \(shellArgument(endpoint.host)) -p \(endpoint.port) -t '#' -C 1"
            },
        ]
    }

    private static func uriService(
        name: String,
        scheme: String,
        userInfo: String? = nil,
        envName: String? = nil
    ) -> [ContainerPortQuickActionTemplate] {
        var templates: [ContainerPortQuickActionTemplate] = [
            .copyAddress(name),
            .copyURI(name, scheme: scheme, userInfo: userInfo),
        ]
        if let envName {
            templates.append(.copyEnvironmentSnippet(name) { endpoint in
                let uri = makeURI(scheme: scheme, endpoint: endpoint, userInfo: userInfo)
                return "\(envName)=\(uri)"
            })
        }
        templates.append(.tcpHealthCheck(name))
        return templates
    }

    private static func httpService(_ name: String, scheme: String = "http") -> [ContainerPortQuickActionTemplate] {
        [
            .openURL(name, scheme: scheme),
            .copyURL(name, scheme: scheme),
            .curlHealthCheck(name, scheme: scheme),
        ]
    }

    private static func httpAPIService(_ name: String, scheme: String = "http", envName: String) -> [ContainerPortQuickActionTemplate] {
        httpService(name, scheme: scheme) + [
            .copyEnvironmentSnippet(name) { endpoint in
                guard let url = makeURL(scheme: scheme, endpoint: endpoint) else { return nil }
                return "\(envName)=\(url)"
            },
        ]
    }

    private static func webServiceName(image: String, containerPort: Int) -> String? {
        for profile in webProfiles where profile.matches(image: image, port: containerPort) {
            return profile.name
        }
        return nil
    }

    private static func normalizedImageName(_ imageName: String) -> String {
        imageName
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
    }

    private static func imageMatches(_ image: String, _ needles: [String]) -> Bool {
        needles.contains { image.contains($0) }
    }

    private static func servicePortMatches(
        image: String,
        tokens: [String],
        port: Int,
        defaultPorts: Set<Int>
    ) -> Bool {
        defaultPorts.contains(port) || (imageMatches(image, tokens) && !likelyWebPorts.contains(port))
    }

    private static let likelyWebPorts: Set<Int> = [
        80, 443, 3000, 3001, 4200, 5000, 5173, 5601, 7000, 7474, 8000, 8008, 8080, 8081,
        8088, 8090, 8123, 8200, 8443, 8500, 8787, 8834, 8888, 8983, 9000, 9001, 9090,
        9093, 9443, 10000, 18083
    ]

    private static let httpsPorts: Set<Int> = [443, 7473, 8443, 8883, 9443]

    private static let webProfiles: [ContainerWebServiceProfile] = [
        .init(name: "Nginx", tokens: ["nginx"]),
        .init(name: "Apache HTTP", tokens: ["httpd", "apache"]),
        .init(name: "Caddy", tokens: ["caddy"]),
        .init(name: "Traefik", tokens: ["traefik"]),
        .init(name: "HAProxy", tokens: ["haproxy"]),
        .init(name: "Envoy", tokens: ["envoy"]),
        .init(name: "Tomcat", tokens: ["tomcat"]),
        .init(name: "Jetty", tokens: ["jetty"]),
        .init(name: "Node", tokens: ["node", "nextjs", "vite", "react", "angular", "bun", "deno"]),
        .init(name: "WordPress", tokens: ["wordpress"]),
        .init(name: "Ghost", tokens: ["ghost"]),
        .init(name: "Drupal", tokens: ["drupal"]),
        .init(name: "Joomla", tokens: ["joomla"]),
        .init(name: "Grafana", tokens: ["grafana"]),
        .init(name: "Prometheus", tokens: ["prometheus"], ports: [9090]),
        .init(name: "Alertmanager", tokens: ["alertmanager"], ports: [9093]),
        .init(name: "Kibana", tokens: ["kibana"], ports: [5601]),
        .init(name: "OpenSearch Dashboards", tokens: ["opensearch-dashboards"], ports: [5601]),
        .init(name: "Portainer", tokens: ["portainer"], ports: [8000, 9000, 9443]),
        .init(name: "Jenkins", tokens: ["jenkins"], ports: [8080]),
        .init(name: "Keycloak", tokens: ["keycloak"], ports: [8080, 8443]),
        .init(name: "SonarQube", tokens: ["sonarqube"], ports: [9000]),
        .init(name: "Adminer", tokens: ["adminer"]),
        .init(name: "phpMyAdmin", tokens: ["phpmyadmin"]),
        .init(name: "pgAdmin", tokens: ["pgadmin"]),
        .init(name: "Mongo Express", tokens: ["mongo-express"]),
        .init(name: "Redis Commander", tokens: ["redis-commander"]),
        .init(name: "Airflow", tokens: ["airflow"], ports: [8080]),
        .init(name: "Superset", tokens: ["superset"], ports: [8088]),
        .init(name: "Metabase", tokens: ["metabase"], ports: [3000]),
        .init(name: "n8n", tokens: ["n8nio/n8n", "n8n"], ports: [5678]),
        .init(name: "NocoDB", tokens: ["nocodb"], ports: [8080]),
        .init(name: "Directus", tokens: ["directus"], ports: [8055]),
        .init(name: "Strapi", tokens: ["strapi"], ports: [1337]),
        .init(name: "Hasura", tokens: ["hasura"], ports: [8080]),
        .init(name: "Gitea", tokens: ["gitea"], ports: [3000, 80, 443]),
        .init(name: "GitLab", tokens: ["gitlab"], ports: [80, 443, 8080]),
        .init(name: "Mattermost", tokens: ["mattermost"], ports: [8065]),
        .init(name: "Verdaccio", tokens: ["verdaccio"], ports: [4873]),
        .init(name: "Nexus", tokens: ["nexus"], ports: [8081]),
        .init(name: "Docker Registry", tokens: ["registry"], ports: [5000]),
        .init(name: "Home Assistant", tokens: ["homeassistant", "home-assistant"], ports: [8123]),
        .init(name: "Uptime Kuma", tokens: ["uptime-kuma"], ports: [3001]),
        .init(name: "Umami", tokens: ["umami"], ports: [3000]),
        .init(name: "Plausible", tokens: ["plausible"], ports: [8000])
    ]
}

private struct ContainerWebServiceProfile {
    var name: String
    var tokens: [String]
    var ports: Set<Int>?

    init(name: String, tokens: [String], ports: Set<Int>? = nil) {
        self.name = name
        self.tokens = tokens
        self.ports = ports
    }

    func matches(image: String, port: Int) -> Bool {
        guard tokens.contains(where: { image.contains($0) }) else { return false }
        return ports?.contains(port) ?? true
    }
}

private struct ContainerPortQuickActionTemplate {
    var kind: ContainerPortQuickActionKind
    var serviceName: String
    var scheme: String?
    var systemImage: String
    var makeValue: (ContainerPortEndpoint) -> String?

    func target(endpoint: ContainerPortEndpoint) -> ContainerBrowserPortTarget? {
        guard let value = makeValue(endpoint) else { return nil }
        let url = kind == .openURL ? URL(string: value) : nil
        guard kind != .openURL || url != nil else { return nil }

        return ContainerBrowserPortTarget(
            title: serviceName,
            url: url,
            copyValue: kind == .openURL ? nil : value,
            action: kind,
            source: endpoint.source,
            scheme: scheme ?? url?.scheme ?? "",
            protocolName: endpoint.protocolName,
            host: endpoint.host,
            port: endpoint.port,
            hostPort: endpoint.hostPort,
            containerPort: endpoint.containerPort,
            systemImage: systemImage
        )
    }

    static func openURL(_ serviceName: String, scheme: String = "http") -> ContainerPortQuickActionTemplate {
        ContainerPortQuickActionTemplate(
            kind: .openURL,
            serviceName: serviceName,
            scheme: scheme,
            systemImage: "safari"
        ) { endpoint in
            makeURL(scheme: scheme, endpoint: endpoint)
        }
    }

    static func copyAddress(_ serviceName: String) -> ContainerPortQuickActionTemplate {
        ContainerPortQuickActionTemplate(
            kind: .copyAddress,
            serviceName: serviceName,
            scheme: nil,
            systemImage: "doc.on.doc"
        ) { endpoint in
            endpoint.address
        }
    }

    static func copyURL(_ serviceName: String, scheme: String = "http") -> ContainerPortQuickActionTemplate {
        ContainerPortQuickActionTemplate(
            kind: .copyURL,
            serviceName: serviceName,
            scheme: scheme,
            systemImage: "link"
        ) { endpoint in
            makeURL(scheme: scheme, endpoint: endpoint)
        }
    }

    static func copyURI(
        _ serviceName: String,
        scheme: String,
        userInfo: String? = nil,
        path: String? = nil
    ) -> ContainerPortQuickActionTemplate {
        ContainerPortQuickActionTemplate(
            kind: .copyConnectionString,
            serviceName: serviceName,
            scheme: scheme,
            systemImage: "link"
        ) { endpoint in
            makeURI(scheme: scheme, endpoint: endpoint, userInfo: userInfo, path: path)
        }
    }

    static func copyEnvironmentSnippet(
        _ serviceName: String,
        makeValue: @escaping (ContainerPortEndpoint) -> String?
    ) -> ContainerPortQuickActionTemplate {
        ContainerPortQuickActionTemplate(
            kind: .copyEnvironmentSnippet,
            serviceName: serviceName,
            scheme: nil,
            systemImage: "text.badge.plus",
            makeValue: makeValue
        )
    }

    static func copyCLICommand(
        _ serviceName: String,
        makeValue: @escaping (ContainerPortEndpoint) -> String?
    ) -> ContainerPortQuickActionTemplate {
        ContainerPortQuickActionTemplate(
            kind: .copyCLICommand,
            serviceName: serviceName,
            scheme: nil,
            systemImage: "terminal",
            makeValue: makeValue
        )
    }

    static func copyHealthCheckCommand(
        _ serviceName: String,
        makeValue: @escaping (ContainerPortEndpoint) -> String?
    ) -> ContainerPortQuickActionTemplate {
        ContainerPortQuickActionTemplate(
            kind: .copyHealthCheckCommand,
            serviceName: serviceName,
            scheme: nil,
            systemImage: "stethoscope",
            makeValue: makeValue
        )
    }

    static func curlHealthCheck(_ serviceName: String, scheme: String = "http") -> ContainerPortQuickActionTemplate {
        .copyHealthCheckCommand(serviceName) { endpoint in
            guard let url = makeURL(scheme: scheme, endpoint: endpoint) else { return nil }
            return "curl -fsS \(shellArgument(url))"
        }
    }

    static func tcpHealthCheck(_ serviceName: String) -> ContainerPortQuickActionTemplate {
        .copyHealthCheckCommand(serviceName) { endpoint in
            "nc -vz \(shellArgument(endpoint.host)) \(endpoint.port)"
        }
    }
}

private func makeURL(scheme: String, endpoint: ContainerPortEndpoint) -> String? {
    var components = URLComponents()
    components.scheme = scheme
    components.host = endpoint.host
    components.port = endpoint.port
    return components.url?.absoluteString
}

private func makeURI(
    scheme: String,
    endpoint: ContainerPortEndpoint,
    userInfo: String? = nil,
    path: String? = nil
) -> String {
    let userPrefix = userInfo.map { "\($0)@" } ?? ""
    let pathSuffix = path.map { "/\($0)" } ?? ""
    return "\(scheme)://\(userPrefix)\(endpoint.address)\(pathSuffix)"
}

private func shellArgument(_ value: String) -> String {
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._/:@[]"))
    if !value.isEmpty, value.unicodeScalars.allSatisfy({ allowed.contains($0) }) {
        return value
    }
    return ShellEscaper.singleQuoted(value)
}
