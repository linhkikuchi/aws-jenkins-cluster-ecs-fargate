output "jenkins_generated_key" {
  value = "${aws_key_pair.jenkins_generated_key.public_key}"
}