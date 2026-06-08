resource "kubernetes_config_map" "superset_config" {
  metadata {
    name      = "superset-config"
    namespace = kubernetes_namespace.superset_ns.metadata[0].name
  }

  data = {
    "superset_config.py" = <<-EOT
      # Superset configuration
      
      # Feature flags
      FEATURE_FLAGS = {
          "ALERTS_ATTACH_REPORTS": True,
          "ALLOW_FULL_CSV_EXPORT": True,
          "CACHE_UPDATER": True,
          "DASHBOARD_CROSS_FILTERS": True,
          "DASHBOARD_NATIVE_FILTERS": True,
          "DISALLOW_NON_CUBE_METRICS": False,
          "EDIT_DATASET_UI": True,
          "ENABLE_ADVANCED_NATIVE_FORMULAS": True,
          "ENABLE_JAVASCRIPT_CONTROLS": True,
          "ENABLE_TEMPLATE_PROCESSING": True,
          "LISTVIEWS_DEFAULT_PAGINATION": 25,
          "ROW_LIMIT": 10000,
          "SUPERSET_SQLLAB_BACKEND_PERSISTENCE": True,
          "THUMBNAILS": True,
          "THUMBNAILS_USE_HEADLESS_BROWSER": True,
          "VERSIONED_FC": True,
      }
      
      # Timeout for SQL Lab queries (in seconds)
      SQLLAB_TIMEOUT = 300
      
      # SQL Alchemy Pool configuration
      SQLALCHEMY_POOL_SIZE = 10
      SQLALCHEMY_POOL_RECYCLE = 3600
      SQLALCHEMY_ECHO = False
      
      # Data cache config
      CACHE_TYPE = "SimpleCache"
      CACHE_DEFAULT_TIMEOUT = 300
      
      # Celery configuration
      CELERY_CONFIG = {
          "broker_url": "",  # Set via ENV variable
          "result_backend": "",  # Set via ENV variable
          "flower_port": 5555,
          "default_queue": "default",
          "broker_pool_limit": 10,
          "broker_connection_retry_on_startup": True,
      }
      
      # Row limit for SQL Lab
      SQLLAB_DEFAULT_DBID = 1
      SQLLAB_DEFAULT_SCHEMA = ""
      
      # Dashboard defaults
      DASHBOARD_AUTO_REFRESH_INTERVAL = 5
      DASHBOARD_CACHING = True
      
      # Chart cache TTL
      SCREENSHOT_EACH_CELERY_TASK_ATTEMPTS = 2
      SCREENSHOT_SELENIUM_BROWSER = "firefox"
      
      # Timezone
      TIMEZONE = "UTC"
      
      # Update these via environment variables
      # DATABASE_URI set via ENV
      # SUPERSET_SECRET_KEY set via ENV
    EOT
  }

  depends_on = [
    kubernetes_namespace.superset_ns
  ]
}
