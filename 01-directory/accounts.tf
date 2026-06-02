# ==============================================================================
# SSH Key Pair
# Generated fresh each deploy — private key written to keys/ (gitignored)
# ==============================================================================

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  content         = tls_private_key.ssh.private_key_openssh
  filename        = "./keys/Private_Key"
  file_permission = "0600"
}

resource "local_file" "public_key" {
  content         = tls_private_key.ssh.public_key_openssh
  filename        = "./keys/Private_Key.pub"
  file_permission = "0644"
}

# ==============================================================================
# Administrator Passwords
# Strong random passwords for admin and local Windows account.
# Stored as sensitive outputs in tfstate — retrieve with get_password.sh.
# ==============================================================================

resource "random_password" "admin_password" {
  length           = 24
  special          = true
  override_special = "_-."
}

resource "random_password" "windows_local_admin_password" {
  length           = 24
  special          = true
  override_special = "_-."
}

# ==============================================================================
# AD User Passwords
# Memorable word + 6-digit number format — easy to type, meets AD complexity.
# ==============================================================================

locals {
  memorable_words = [
    "bright", "simple", "orange", "window", "little",
    "people", "friend", "yellow", "animal", "family",
    "circle", "moment", "summer", "button", "planet",
    "rocket", "silver", "forest", "stream", "butter",
    "castle", "wonder", "gentle", "driver", "coffee"
  ]

  ad_users = {
    jsmith = "John Smith"
    rpatel = "Raj Patel"
    akumar = "Amit Kumar"
    edavis = "Emily Davis"
  }
}

resource "random_shuffle" "word" {
  for_each     = local.ad_users
  input        = local.memorable_words
  result_count = 1
}

resource "random_integer" "num" {
  for_each = local.ad_users
  min      = 100000
  max      = 999999
}

locals {
  admin_password               = "A${random_password.admin_password.result}"
  windows_local_admin_password = "A${random_password.windows_local_admin_password.result}"

  passwords = {
    for user in keys(local.ad_users) :
    user => format(
      "%s-%d",
      random_shuffle.word[user].result[0],
      random_integer.num[user].result
    )
  }

  jsmith_password = local.passwords["jsmith"]
  edavis_password = local.passwords["edavis"]
  rpatel_password = local.passwords["rpatel"]
  akumar_password = local.passwords["akumar"]
}
