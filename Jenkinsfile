pipeline {
  agent any
  environment {
    FRONTEND_DIR = 'Frontend-ReactJs/event-management-dashboard'
    BACKEND_DIR = 'Backend-Java/Event_Managment'
    Kubernetes_Dir = 'Kubernetes'
    }
    stages {
        stage('clone') {
            steps {
                git branch: 'main', url:'https://github.com/yogeshpri/Capstone-Project.git'
            }
        }
        // stage('build frontend'){
        //     steps{
        //         dir("${FRONTEND_DIR}") {
        //             sh 'docker build -t frontend .'
        //             echo "Docker Frontend image build sucessfully completed."
        //             withCredentials([usernamePassword(credentialsId: 'Docker_Hub_Credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
        //                 sh 'docker login -u $DOCKER_USER -p $DOCKER_PASS'
        //                 sh 'docker tag frontend $DOCKER_USER/frontend:v9'
        //                 sh 'docker push $DOCKER_USER/frontend:v9'
        //             }
        //         }
        //     }
        // }
        // stage('build backend'){
        //     steps{
        //         dir("${BACKEND_DIR}") {
        //             sh 'docker build -t backend .'
        //             echo "Docker Backend image build sucessfully completed."
        //             withCredentials([usernamePassword(credentialsId: 'Docker_Hub_Credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
        //                 sh 'docker login -u $DOCKER_USER -p $DOCKER_PASS'
        //                 sh 'docker tag backend $DOCKER_USER/backend:v9'
        //                 sh 'docker push $DOCKER_USER/backend:v9'
        //             }
        //         }
        //     } 
        // }  
        stage('build backend'){
            steps{
                dir("${Kubernetes_Dir}") {
                    sh 'kubectl apply -f .'
                    }
                }
            } 
        }  
    
}
