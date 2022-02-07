/*
El bloque dinamico sirve para no tener que repetir varias veces una configuracion similar para cualquier tipo de instancia
o servicio que se quiera crear con varios valores.
*/
locals {
    ingress_rules [{
        port        = 443
        description = "Port 443"
    },
    {
        port        = 80
        description = "Port 80"
    }]  
}


resource "aws_security_grou" "main" {
    name = "security-group-name"
    vpc_id = data.aws_vpc.vpc-name.id

    dynamic "ingress" {
        for_each = local.ingress_rules

        content {
            description = ingress.value.description
            from_port   = ingress.value.port
            to_port     = ingress.value.port
            protocol    = "tcp"
            cidr_block  = ["0.0.0.0/0"]
        }
    }
}


#SG sin bloque dinamico

resource "aws_security_grou" "main" {
    name = "security-group-name"
    vpc_id = data.aws_vpc.vpc-name.id

    ingress {
        description = "Port 443"
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_block  = ["0.0.0.0/0"]
    }
    ingress {
        description = "Port 80"
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_block  = ["0.0.0.0/0"]
    }

    tags = {
        tags
    }
}