provider "aws" {
  region = "ap-northeast-1"
}

resource "aws_db_instance" "example" {
  identifier_prefix = "terraform-test-rds"
  engine = "mysql"
  engine_version = "8.0"
  allocated_storage = 8
  instance_class = "db.t2.micro"
  db_name = "example_database"
  username = "admin"
  password = var.db_password
  skip_final_snapshot = true
}


terraform {
  backend "s3" {
    # 앞선 실습에서 생성해 둔 버킷 이름
    bucket = "song-v0822-state"
    key = "stage/data-stores/mysql/terraform.tfstate" # 테라폼 상태 파일
    # 저장할 S3버킷내 > 파일 경로
    region = "ap-northeast-1"
    # 미리 생성한 테이블 이름으로 변경
    dynamodb_table = "terraform-test2-locks"
    encrypt = true
  }
}

