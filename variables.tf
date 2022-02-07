variable "my_intance_type" {
    type = string
    description = "My instance type"
}
variable "instance_tags" {
    type = object({
        Name = string
        NumberEJ = number
    })

}