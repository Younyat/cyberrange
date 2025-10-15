echo "=== 4. Lanzando Terraform ==="

terraform init
echo "Pausando 30 segundos antes de 'init'..."
sleep 30
terraform plan
echo "Pausando 30 segundos antes de 'plan'..."
sleep 30
terraform apply -auto-approve -parallelism=4
echo "Pausando 30 segundos antes de 'apply'..."
sleep 30
