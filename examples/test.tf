provider "shell" {}


//test complete data resource
data "shell_script" "test" {
  lifecycle_commands {
    read = <<EOF
      echo '{"commit_id": 23}' >&3
    EOF
  }
}

//test complete data resource
data "shell_script" "test_bis" {
  lifecycle_commands {
    read = <<EOF
      echo '{"commit_id": "23"}' >&3
    EOF
  }
}

//data resource does not work -> invalid json
/*data "shell_script" "test_tri" {
  lifecycle_commands {
    read = <<EOF
      echo '{"commit_id": test}' >&3
    EOF
  }
}*/

output "commit_id" {
  value = data.shell_script.test.output["commit_id"]
}

output "commit_id_bis" {
  value = data.shell_script.test_bis.output["commit_id"]
}


/*output "commit_id_tri" {
  value = data.shell_script.test_tri.output["commit_id"] // returns data.shell_script.test_tri.output is null
}*/

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
