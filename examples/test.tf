provider "shell" {}


//test complete data resource 
resource "shell_script" "test" {
  lifecycle_commands {
    create = <<EOF
      touch test.sh
      while 1 do echo test > test.sh >&3
    EOF
    delete = "rm -rf test.sh"
  }
  timeouts {
    create = "1m"
    delete = "2m"
  }
}

//test resource with no read or update
resource "shell_script" "test2" {
  lifecycle_commands {
    create = <<EOF
      out='{"commit_id": "b8f2b8b", "environment": "$yolo", "tags_at_commit": "sometags", "project": "someproject", "current_date": "09/10/2014", "version": "someversion"}'
      touch test2.json
      echo $out >> test2.json
      cat test2.json >&3
    EOF
    delete = "rm -rf test2.json"
  }

  environment = {
    yolo = "yolo"
  }
}

//test resource with no update
resource "shell_script" "test3" {
  lifecycle_commands {
    create = <<EOF
      out='{"commit_id": "b8f2b8b", "environment": "$yolo", "tags_at_commit": "sometags", "project": "someproject", "current_date": "09/10/2014", "version": "someversion"}'
      touch test3.json
      echo $out >> test3.json
      cat test3.json >&3
    EOF
    read   = "cat test3.json >&3"
    delete = "rm -rf test3.json"
  }

  environment = {
    yolo = "yolo2"

  }
}

//test resource with no read
resource "shell_script" "test4" {
  lifecycle_commands {
    create = <<EOF
      out='{"commit_id": "b8f2b8b", "environment": "$yolo", "tags_at_commit": "sometags", "project": "someproject", "current_date": "09/10/2014", "version": "someversion"}'
      touch test4.json
      echo $out >> test4.json
      cat test4.json >&3
    EOF
    update = <<EOF
      rm -rf test4.json
      out='{"commit_id": "b8f2b8b", "environment": "$yolo", "tags_at_commit": "sometags", "project": "someproject", "current_date": "09/10/2014", "version": "someversion"}'
      touch test4.json
      echo $out >> test4.json
      cat test4.json >&3
    EOF
    delete = "rm -rf test4.json"
  }

  environment = {
    yolo = "yolo"
  }
}

//test complete resource
/*resource "shell_script" "test5" {
  lifecycle_commands {
    create = file("${path.module}/scripts/create.sh")
    read   = file("${path.module}/scripts/read.sh")
    update = file("${path.module}/scripts/update.sh")
    delete = file("${path.module}/scripts/delete.sh")
  }

  working_directory = "${path.module}"

  environment = {
    yolo = "yolo"
    ball = "room"
  }
  timeouts {
    create = "1m"
    delete = "1m"
  }
}

output "commit_id2" {
  value = shell_script.test5.output["commit_id"]
}
*/
//resource with triggers
resource "shell_script" "test6" {
  lifecycle_commands {
    create = file("${path.module}/scripts/create.sh")
    read   = file("${path.module}/scripts/read.sh")
    delete = file("${path.module}/scripts/delete.sh")
  }

  working_directory = "${path.module}"

  environment = {
    yolo = "yolo"
    ball = "room"
  }

  triggers = {
    abc = 123
  }
}