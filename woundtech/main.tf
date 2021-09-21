module "ecs_woundtech" {
source = "../module/"
secret_key = "Enter user secret key details"
access_key = "Enter user secret key details"
app_name = "wt-nginx"
app_environment = "Dev"
aws_region = "eu-west-1"
app_sources_cidr = ["0.0.0.0/0"]
host_sources_cidr = ["0.0.0.0/0"]
aws_key_pair_name = "Enter valid key pair for ec2 creation"
nginx_app_image = "nginx:alpine"
}
