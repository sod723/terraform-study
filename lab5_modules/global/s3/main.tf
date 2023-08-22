provider "aws" {
  region = "ap-northeast-1"
}
resource "aws_s3_bucket" "terraform_state" {
  bucket = "song-v0822-state" # 유일한 값을 입력해야 함
  # 실수로 삭제되는 것 방지
#  lifecycle {
#    prevent_destroy = true
#  }
  # 코드 이력 관리를 위해 상태 파일의 버전 관리를 활성화
  versioning {
    enabled = true
  }
  # 서버 측 암호화를 활성화
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}
# DynamoDB 테이블 생성
resource "aws_dynamodb_table" "terraform_locks" {
  name = "terraform-test2-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}
# backend 재지정하여 로컬이 아닌 s3에 저장
terraform {
  backend "s3" {
  # 미리 생성한 버킷 이름으로 변경
  bucket = "song-v0822-state"
  key = "global/s3/terraform.tfstate" # 테라폼 상태 파일 저장할 S3 버킷 내 파일 경로
  region = "ap-northeast-1"
  # 미리 생성한 테이블 이름으로 변경
  dynamodb_table = "terraform-test2-locks"
  encrypt = true
  }
}
