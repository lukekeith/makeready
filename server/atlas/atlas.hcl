// Atlas Configuration for MakeReady Server
// https://atlasgo.io/

// Variables from environment
variable "database_url" {
  type    = string
  default = getenv("DATABASE_URL")
}

variable "direct_url" {
  type    = string
  default = getenv("DIRECT_URL")
}

// PostgreSQL provider
env "local" {
  src = "file://.schema.hcl"
  url = "${var.database_url}?sslmode=disable"
  // Local dev database for Atlas diffing
  dev = "postgres://postgres:postgres@localhost:5434/atlas_dev_template?sslmode=disable&search_path=public"

  migration {
    dir = "file://migrations"
  }

  diff {
    skip {
      // Don't drop columns - use soft delete pattern
      drop_column = true
    }
  }
}

env "production" {
  src = "file://.schema.hcl"
  url = var.database_url

  migration {
    dir    = "file://migrations"
    format = atlas
  }

  diff {
    skip {
      drop_column = true
    }
  }
}

env "test" {
  src = "file://.schema.hcl"
  url = "postgres://postgres:postgres@localhost:5432/makeready_test?sslmode=disable"
  dev = "docker://postgres/16/dev?search_path=public"

  migration {
    dir = "file://migrations"
  }
}

// Lint configuration
lint {
  destructive {
    error = true
  }

  // Warn on potential data loss
  data_depend {
    error = true
  }
}
