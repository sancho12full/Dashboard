my_instance_type = "t2.micro"

intance_tags = {
    Name = "ec2_instance"
    NumberEJ = 123
}

/*
En caso de que tengamos varios environments el nombre de este archivo puede variar a prod, dev, etc. Para definir que archivo de variables
utilizaria se usa 'terraform apply -var-file dev.tfvars' por ejemplo.
Las variables de entorno se definen en el sistema como TF_VAR_variable-name
*/