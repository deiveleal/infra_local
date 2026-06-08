####
# Configuration for Superset
####
namespace_name = "superset-ns"

####
# Superset Admin Credentials
####
username = "adminuser"
password = "adminuser"

####
# Flask Secret Key (change this in production)
####
secret_key = "your-secret-key-here-change-me"

####
# PostgreSQL Configuration (for Superset metastore)
####
postgresql_host     = "postgresql.postgresql-ns"
postgresql_port     = 5432
postgresql_user     = "adminuser"
postgresql_password = "adminuser"
postgresql_db       = "superset_db"

####
# RabbitMQ Configuration (for Celery broker)
####
rabbitmq_host     = "rabbitmq.rabbitmq-ns"
rabbitmq_port     = 5672
rabbitmq_user     = "adminuser"
rabbitmq_password = "adminuser"
