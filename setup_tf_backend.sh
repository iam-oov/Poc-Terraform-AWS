#!/bin/bash
set -e # Salir inmediatamente si un comando termina con un estado no cero.

# --- Configuration ---
PRE_TERRAFORM_DIR="./00-tf-infra"
APP_TERRAFORM_DIR="./01-tf"
GENERATED_VARIABLES_TF_FILENAME="auto_variables.tf"
GENERATED_BACKEND_TF_FILENAME="auto_backend.tf"

ECR_REPOSITORY_NAME="poc-hello-world"
AWS_REGION_FOR_BACKEND_RESOURCES="us-east-1"
TF_BACKEND_KEY="states/${ECR_REPOSITORY_NAME}/terraform.tfstate"

# Output names from output.tf in pre-terraform dir
S3_BUCKET_OUTPUT_NAME="s3_bucket_name"
DYNAMODB_TABLE_OUTPUT_NAME="dynamodb_lock_table_name"
# --- End Configuration ---

FULL_GENERATED_BACKEND_TF_PATH="${APP_TERRAFORM_DIR}/${GENERATED_BACKEND_TF_FILENAME}"
FULL_GENERATED_VARIABLES_TF_PATH="${APP_TERRAFORM_DIR}/${GENERATED_VARIABLES_TF_FILENAME}"

echo "**********************************************************************"
echo "Script de Bootstrapping para Backend S3 de Terraform (Dos Etapas)"
echo "Este script:"
echo "1. Ejecutará Terraform en '${PRE_TERRAFORM_DIR}' para crear el bucket S3 y la tabla DynamoDB."
echo "2. Generará '${GENERATED_BACKEND_TF_FILENAME}' en '${APP_TERRAFORM_DIR}' para tu aplicación principal."
echo "**********************************************************************"
echo ""
echo "Prerrequisitos para el directorio de aprovisionamiento del backend ('${PRE_TERRAFORM_DIR}'):"
echo "1. Debe contener código Terraform para crear un bucket S3 y una tabla DynamoDB."
echo "2. Debe definir outputs de Terraform llamados '${S3_BUCKET_OUTPUT_NAME}' y '${DYNAMODB_TABLE_OUTPUT_NAME}'."
echo "3. Esta configuración DEBE USAR UN BACKEND LOCAL (es decir, no tener un bloque 'terraform { backend \"s3\" {...} }')."
echo ""
echo "Prerrequisitos para el directorio de la aplicación ('${APP_TERRAFORM_DIR}'):"
echo "1. Este directorio debe existir o el script intentará crearlo."
echo "2. Cualquier archivo '${GENERATED_BACKEND_TF_FILENAME}' preexistente en este directorio será SOBRESCRITO."
echo "3. Cualquier archivo '${GENERATED_VARIABLES_TF_FILENAME}' preexistente en este directorio será SOBRESCRITO."
echo "**********************************************************************"
echo ""

# Loop to ensure a valid response (optional, but improves UX)
while true; do
    read -r -p "Has cumplido los prerrequisitos y estás listo para continuar? (yes/no): " confirmation
    echo "" # New line for readability

    # Convert the input to lowercase for easier comparison
    confirmation_lower=$(echo "$confirmation" | tr '[:upper:]' '[:lower:]')

    case "$confirmation_lower" in
        yes|y)
            echo "Confirmación recibida ('$confirmation'). Continuando con el script..."
            break # Exit the loop and continue with the script
            ;;
        no|n)
            echo "El usuario eligió no continuar ('$confirmation'). Abortando script."
            exit 1 # Exit the script
            ;;
        *)
            echo "Entrada inválida ('$confirmation'). Por favor, responde 'yes' (o 'y') o 'no' (o 'n')."
            # The loop will continue asking for input
            ;;
    esac
done

# verify pre-terraform dir exists
if [ ! -d "${PRE_TERRAFORM_DIR}" ]; then
    echo "Error: El directorio de aprovisionamiento del backend '${PRE_TERRAFORM_DIR}' no existe."
    exit 1
fi

# verify app-terraform dir exists
if [ ! -d "${APP_TERRAFORM_DIR}" ]; then
    echo "Información: El directorio de la aplicación '${APP_TERRAFORM_DIR}' no existe. Creándolo..."
    mkdir -p "${APP_TERRAFORM_DIR}"
    if [ $? -ne 0 ]; then
        echo "Error: No se pudo crear el directorio de la aplicación '${APP_TERRAFORM_DIR}'."
        exit 1
    fi
fi

# save current working directory to return to it later
SCRIPT_CWD=$(pwd)

echo ""
echo "--- Ejecutando Terraform en el directorio de aprovisionamiento del backend: ${PRE_TERRAFORM_DIR} ---"
cd "${PRE_TERRAFORM_DIR}"

echo "--- Inicializando Terraform en '${PRE_TERRAFORM_DIR}' (usando backend local) ---"
terraform init -input=false

echo "--- Aplicando cambios en '${PRE_TERRAFORM_DIR}' (para crear el bucket S3 y la tabla DynamoDB) ---"
terraform apply -auto-approve -input=false -var="AWS_REGION=${AWS_REGION_FOR_BACKEND_RESOURCES}"

echo "--- Obteniendo Outputs de Terraform desde '${PRE_TERRAFORM_DIR}' ---"
TF_OUTPUT_S3_BUCKET_VALUE=$(terraform output -raw "${S3_BUCKET_OUTPUT_NAME}")
if [ -z "${TF_OUTPUT_S3_BUCKET_VALUE}" ]; then
    echo "Error: El output de Terraform '${S3_BUCKET_OUTPUT_NAME}' desde '${PRE_TERRAFORM_DIR}' está vacío."
    echo "Por favor, asegúrate de que este output esté correctamente definido y que el recurso se haya creado."
    cd "${SCRIPT_CWD}" # return to original working directory
    exit 1
fi
echo "Nombre del Bucket S3 obtenido: ${TF_OUTPUT_S3_BUCKET_VALUE}"

TF_OUTPUT_DYNAMODB_TABLE_VALUE=$(terraform output -raw "${DYNAMODB_TABLE_OUTPUT_NAME}")
if [ -z "${TF_OUTPUT_DYNAMODB_TABLE_VALUE}" ]; then
    echo "Error: El output de Terraform '${DYNAMODB_TABLE_OUTPUT_NAME}' desde '${PRE_TERRAFORM_DIR}' está vacío."
    echo "Por favor, asegúrate de que este output esté correctamente definido y que el recurso se haya creado."
    cd "${SCRIPT_CWD}" # return to original working directory
    exit 1
fi
echo "Nombre de la Tabla DynamoDB obtenido: ${TF_OUTPUT_DYNAMODB_TABLE_VALUE}"

# return to original working directory
cd "${SCRIPT_CWD}"

# generate backend.tf file
echo ""
echo "--- Generando el archivo '${GENERATED_BACKEND_TF_FILENAME}' en '${APP_TERRAFORM_DIR}' ---"

cat > "${FULL_GENERATED_BACKEND_TF_PATH}" <<EOL
# !!! DO NOT MODIFY THIS FILE MANUALLY !!!
# File generated by 'setup_tf_backend.sh' dont modify this file manually
# unless you know what you are doing

terraform {
  backend "s3" {
    bucket         = "${TF_OUTPUT_S3_BUCKET_VALUE}"
    key            = "${TF_BACKEND_KEY}"
    region         = "${AWS_REGION_FOR_BACKEND_RESOURCES}"
    dynamodb_table = "${TF_OUTPUT_DYNAMODB_TABLE_VALUE}"
    encrypt        = true
  }
}
EOL

echo ""
echo "Se generó exitosamente '${FULL_GENERATED_BACKEND_TF_PATH}' con el siguiente contenido:"
echo "--------------------------------------------------"
cat "${FULL_GENERATED_BACKEND_TF_PATH}"
echo "--------------------------------------------------"

# generate variables.tf file
echo ""
echo "--- Generando el archivo '${GENERATED_VARIABLES_TF_FILENAME}' en '${APP_TERRAFORM_DIR}' ---"

cat > "${FULL_GENERATED_VARIABLES_TF_PATH}" <<EOL
# !!! DO NOT MODIFY THIS FILE MANUALLY !!!
# File generated by 'setup_tf_backend.sh' dont modify this file manually
# unless you know what you are doing

variable "AWS_REGION" {
  description = "AWS region for ECR repository"
  type        = string
  default     = "${AWS_REGION_FOR_BACKEND_RESOURCES}"
}

variable "ECR_REPOSITORY_NAME" {
  description = "Name for the ECR repository"
  type        = string
  default     = "${ECR_REPOSITORY_NAME}"
}
EOL

echo ""
echo "Se generó exitosamente '${FULL_GENERATED_VARIABLES_TF_PATH}' con el siguiente contenido:"
echo "--------------------------------------------------"
cat "${FULL_GENERATED_VARIABLES_TF_PATH}"
echo "--------------------------------------------------"
echo "Script finalizado."