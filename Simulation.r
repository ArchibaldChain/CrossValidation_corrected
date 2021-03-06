### An R code for simulation (3.1.1 and 3.1.2)
### This code was executed 1000 times. 

library(lme4)
library(MASS)

#Paths
{
  Code_folder<-"."
  Output_folder<-"."
  data_folder<-"./data_fold"
}


###################

# Sample Size Definition
{
  sample_size<-c(300)
  #sample_size<-c(300,400,500)
  subject_size<-10
  cluster_size<-50
}

# Parameter Definition
{
  beta<-c(0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1)
  # timeCoef<-0.1 We integrated it in the beta
  model_i<-list(c(1:2),c(1:3),c(1:4),c(1:5),c(1:6),c(1:7),c(1:8),c(1:9))  
  #model_i = list(c(1:2), c(1:3))
  model_no<-length(model_i)
  
  DiagX<-1
  meanX<-0
  
  Var_add<-matrix(NA,length(model_i),1)
  for(r in 1:length(model_i)){
      # Var_add = beta'[1:r] * beta'[1:r]
    Var_add[r]<-t(beta[-c(1:as.numeric(max(unlist(model_i[r]))))])%*%beta[-c(1:as.numeric(max(unlist(model_i[r]))))]
  }
  SigEps<-1
  SigInt<-9
  SigSlope<-1
  SigCluster<-9
}

{
  Error_tr<-matrix(data=NA,model_no+1,length(sample_size))
  Error_tr_est<-matrix(data=NA,model_no+1,length(sample_size))
  Error_tr_LMM<-matrix(data=NA,model_no+1,length(sample_size))
  Error_tr_LMM_est<-matrix(data=NA,model_no+1,length(sample_size))
  
  Error_test<-matrix(data=NA,model_no+1,length(sample_size))
  Error_test_GLS<-matrix(data=NA,model_no+1,length(sample_size))
  Error_test_LMM<-matrix(data=NA,model_no+1,length(sample_size))
  
  Correction<-matrix(data=NA,model_no+1,length(sample_size))
  Correction_est<-matrix(data=NA,model_no+1,length(sample_size))
  Correction_GLS<-matrix(data=NA,model_no+1,length(sample_size))
  Correction_GLS_est<-matrix(data=NA,model_no+1,length(sample_size))
  Correction_LMM<-matrix(data=NA,model_no+1,length(sample_size))
  Correction_LMM_est<-matrix(data=NA,model_no+1,length(sample_size))
}

for(s in 1:length(sample_size)){

  #Sample size
  {  
    n<-sample_size[s]
    Nsubjects<-n/subject_size
    Nclusters<-n/cluster_size
  }
  
  # Creating the varinace
  {
    Z<-matrix(data=0,nrow=n,ncol=2*Nsubjects)
    
    for(l in 1:Nsubjects)  {
      rowindex1<-(1+(l-1)*subject_size)
      rowindex2<-l*subject_size
      
      Z[rowindex1:rowindex2,2*l-1]<-rep(1,subject_size)
      Z[rowindex1:rowindex2,2*l]<-c(1:subject_size)  
    }
    
    Z_clusters<-matrix(data=0,nrow=n,ncol=Nclusters)
    for(l in 1:Nclusters)  {
      rowindex1<-(1+(l-1)*cluster_size)
      rowindex2<-l*cluster_size
      
      Z_clusters[rowindex1:rowindex2,l]<-rep(1,cluster_size)
    }
    
    time<-rep(c(1:subject_size),Nsubjects)
    ID1<-rep(c(1:Nsubjects),each=subject_size)
    ID2<-rep(c(1:Nclusters),each=cluster_size)
    
    V<-Z%*%diag(rep(c(SigInt,SigSlope),times=Nsubjects))%*%t(Z)+Z_clusters%*%diag(rep(SigCluster,times=Nclusters))%*%t(Z_clusters)+diag(SigEps,n)
    
    # V_without_clusters
    V_wo_Cluster<-Z%*%diag(rep(c(SigInt,SigSlope),times=Nsubjects))%*%t(Z)+diag(SigEps,n)
    
    # VCluster<-Z%*%diag(rep(c(SigInt,SigSlope),times=Nsubjects))%*%t(Z)+Z_clusters%*%diag(rep(SigCluster,times=Nclusters))%*%t(Z_clusters)+diag(SigEps,n)
    VClusters<-Z_clusters%*%diag(rep(SigCluster,times=Nclusters))%*%t(Z_clusters)
    V_x<-Z_clusters%*%diag(rep(1,times=Nclusters))%*%t(Z_clusters)+diag(1,n)
    
  }
  
  #Sampling X and Y  
  {
    X_tmp<-NULL
    for(i in 1:(length(beta)-2)){
      X_tmp<-cbind(X_tmp,rep(mvrnorm(1,rep(meanX,n),V_x)))
    }
    
    X<-cbind(rep(1,n),time,X_tmp)
    randomCluster<-rep(mvrnorm(1,rep(0,Nclusters),diag(SigCluster,Nclusters)),each=cluster_size)
    y<-X%*%beta+randomCluster+mvrnorm(1,rep(0,n),V_wo_Cluster)
  }
  
  
  {
    X_minus_i<-matrix(0,n-1,length(beta))
    V_minus_i<-matrix(0,n-1,n-1)
    H_CV<-array(0,dim=c(n,n,length(model_i)))
    H_CV_est<-array(0,dim=c(n,n,length(model_i)))
    H_CV_LMM<-array(0,dim=c(n,n,length(model_i)))
    H_CV_LMM_est<-array(0,dim=c(n,n,length(model_i)))
    
  }
  
  ## Creating H_CV, H_CV_est, training error and correction
  
  #H_CV, H_CV
  for(r in 1:length(model_i)){
    Prefit <- lmer(y ~X[,1:(max(unlist(model_i[r])))]-1+(1|ID1)+(1|ID2)+(time-1|ID1),REML=T)
    
    
    V_est<-Z%*%diag(rep(c(unclass(VarCorr(Prefit))$'ID1.1'[1],unclass(VarCorr(Prefit))$'ID1'[1]),times=Nsubjects))%*%t(Z)+Z_clusters%*%diag(rep(unclass(VarCorr(Prefit))$'ID2'[1],times=Nclusters))%*%t(Z_clusters)+diag(attr(VarCorr(Prefit),"sc")^2,n)
    
    VClusters_est<-Z_clusters%*%diag(rep(unclass(VarCorr(Prefit))$'ID2'[1],times=Nclusters))%*%t(Z_clusters)
    
    V_wo_Cluster_est<-Z%*%diag(rep(c(unclass(VarCorr(Prefit))$'ID1.1'[1],unclass(VarCorr(Prefit))$'ID1'[1]),times=Nsubjects))%*%t(Z)+diag(attr(VarCorr(Prefit),"sc")^2,n)
    
    for(i in 1:n){
      { 
        X_i<-X[i,1:max(unlist(model_i[r]))]
        X_minus_i<-X[-i,1:max(unlist(model_i[r]))]
        V_x_minus_i<-matrix(0,n-1,n-1)
        for(t in (r+1):length(model_i)){
          V_x_minus_i<-V_x_minus_i+beta[t]^2*V_x[-i,-i]
        }
        
        V_minus_i<-as.matrix(V[-i,-i]+V_x_minus_i)
        V_minus_i_solve<-chol2inv(chol(V_minus_i))
        
        H_CV[i,-i,r]<-X_i%*%chol2inv(chol(t(X_minus_i)%*%V_minus_i_solve%*%X_minus_i))%*%t(X_minus_i)%*%V_minus_i_solve
      }
      
      {
        V_minus_i_est_solve<-chol2inv(chol(V_est[-i,-i]))
        
        H_CV_est[i,-i,r]<-X_i%*%chol2inv(chol(t(X_minus_i)%*%V_minus_i_est_solve%*%X_minus_i))%*%t(X_minus_i)%*%V_minus_i_est_solve
      }
    }
    
    # H_CV_LMM and H_CV_LMM_est
    
    H_CVTmp<-matrix(0,n,(n-1))
    H_CVTmp_est<-matrix(0,n,(n-1))
    
    for(i in 1:n){
      H_CVTmp[i,]<-H_CV[i,-i,r]
      H_CVTmp_est[i,]<-H_CV_est[i,-i,r]
    }
    
    
    for(i in 1:n){
      {
        VClusters_minus_i<-as.matrix(VClusters[i,-i])
        VClusters_minus_i_est<-as.matrix(VClusters_est[i,-i])
        V_x_minus_i<-matrix(0,n-1,n-1)
        for(t in (r+1):length(model_i)){
          V_x_minus_i<-V_x_minus_i+beta[t]^2*V_x[-i,-i]
        }
        
        V_minus_i<-as.matrix(V[-i,-i]+V_x_minus_i)
        V_minus_i_solve<-chol2inv(chol(V_minus_i))
        V_minus_i_est_solve<-chol2inv(chol(V_est[-i,-i]))
        
        H_CV_LMM[i,-i,r]<-H_CV[i,-i,r]+t(VClusters_minus_i)%*%V_minus_i_solve%*%(diag(1,n-1)-H_CVTmp[-i,])
        H_CV_LMM_est[i,-i,r]<-H_CV_est[i,-i,r]+t(VClusters_minus_i_est)%*%V_minus_i_est_solve%*%(diag(1,n-1)-H_CVTmp_est[-i,])
        
      }
     }
    
    
    #Correction
    {
      V_x_r<-matrix(0,n,n)
      for(t in (r+1):length(model_i)){
        V_x_r<-V_x_r+beta[t]^2*V_x
      }
      
      Correction[r,s]<-(2/n)*sum(diag(H_CV[,,r]%*%as.matrix(V+V_x_r)))
      Correction_est[r,s]<-(2/n)*sum(diag(H_CV_est[,,r]%*%V_est))
      
      Correction_GLS[r,s]<-(2/n)*(sum(diag(H_CV[,,r]%*%as.matrix(V+V_x_r)))-sum(diag(H_CV[,,r]%*%VClusters)))
      Correction_GLS_est[r,s]<-(2/n)*(sum(diag(H_CV_est[,,r]%*%V_est))-sum(diag(H_CV_est[,,r]%*%VClusters_est)))
      
      Correction_LMM[r,s]<-(2/n)*(sum(diag(H_CV_LMM[,,r]%*%as.matrix(V+V_x_r)))-sum(diag(H_CV_LMM[,,r]%*%VClusters)))
      Correction_LMM_est[r,s]<-(2/n)*(sum(diag(H_CV_LMM_est[,,r]%*%as.matrix(V_est)))-sum(diag(H_CV_LMM_est[,,r]%*%VClusters_est)))
    }
    
    # Error_tr Error_tr_est
    
    {
      y_hat<-H_CV[,,r]%*%y
      y_hat_est<-H_CV_est[,,r]%*%y
      
      y_hat_lmm<-H_CV_LMM[,,r]%*%y
      y_hat_lmm_est<-H_CV_LMM_est[,,r]%*%y
      
      Error_tr[r,s]<-(1/n)*(t(y-y_hat)%*%(y-y_hat))
      Error_tr_est[r,s]<-(1/n)*(t(y-y_hat_est)%*%(y-y_hat_est))
      
      Error_tr_LMM[r,s]<-(1/n)*(t(y-y_hat_lmm)%*%(y-y_hat_lmm))
      Error_tr_LMM_est[r,s]<-(1/n)*(t(y-y_hat_lmm_est)%*%(y-y_hat_lmm_est))
      
    }
    
  }
    
  {
    
    plot( Error_tr[-9], type="o", col="black", ylab = 'error' , main = 'Error Plot')
    par(new = TRUE)
    plot( Error_tr_est[-9], type="o", col="red", ylab = 'error' , main = 'Error Plot')
    par(new=TRUE)
    plot( Error_tr_LMM_est[-9], type="o", col="green", ylab = 'error' )
    par(new = TRUE)
    plot(Error_tr_LMM[-9],type = "l",  col = "blue", ylab = 'error')  
    
  }
  
    
  {
    Correction[model_no+1,s]<-sample_size[s]
    Correction_est[model_no+1,s]<-sample_size[s]
    Error_tr[model_no+1,s]<-sample_size[s]
    Error_tr_est[model_no+1,s]<-sample_size[s]
    
    Correction_GLS[model_no+1,s]<-sample_size[s]
    Correction_GLS_est[model_no+1,s]<-sample_size[s]
    Correction_LMM[model_no+1,s]<-sample_size[s]
    Correction_LMM_est[model_no+1,s]<-sample_size[s]
    Error_tr_LMM[model_no+1,s]<-sample_size[s]
    Error_tr_LMM_est[model_no+1,s]<-sample_size[s]
    
  }
    
  ## Generalization Error
  
  #V_train, V_test, training and test samples
  # Select n-1 from X become X_train
  { 
    n_train<- n-1
    n_test<- n
    Index<-sample.int(n = sample_size[s], size = 1, replace = F)
    y_train<-y[-Index]
    X_train<-X[-Index,]
    V_train<-V[-Index,-Index]
    
    X_tmp<-NULL
    for(i in 1:(length(beta)-2)){
      X_tmp<-cbind(X_tmp,rep(mvrnorm(1,rep(meanX,n),V_x)))
    }
    
    # Simulating X_test from the distribution again
    X_test<-cbind(rep(1,n),time,X_tmp)
  
    randomClusterGLS<-rep(mvrnorm(1,rep(0,Nclusters),diag(SigCluster,Nclusters)),each=cluster_size)
    
    # without cluster error
    new_error<-mvrnorm(1,rep(0,n),V_wo_Cluster)
    
    # y_test is independent from y_train
    y_test<-X_test%*%beta+randomClusterGLS+new_error
    
    # y_test_Cluster using the same cluster from y_train, so y_test_Cluster and 
    # y_train are correlated
    y_test_Cluster<-X_test%*%beta+randomCluster+new_error
    
  }
  
  # test error  
  for(r in 1:length(model_i)){
    V_x_r<-matrix(0,n-1,n-1)
    for(t in (r+1):length(model_i)){
      V_x_r<-V_x_r+beta[t]^2*V_x[-Index,-Index]
    }
    
    V_train_r<-as.matrix(V_train+V_x_r)
    V_train_r_solve<-chol2inv(chol(V_train_r))
    X_test_r<-X_test[,1:max(unlist(model_i[r]))]
    X_train_r<-X_train[,1:max(unlist(model_i[r]))]
    
    y_hat_test<-X_test_r %*% 
        chol2inv(chol(t(X_train_r)%*%V_train_r_solve%*%X_train_r))%*%t(X_train_r)%*%V_train_r_solve%*%y_train # beta_hat
    
    y_hat_test_LMM <- y_hat_test+
        Z_clusters%*%diag(rep(SigCluster,times=Nclusters))%*%t(Z_clusters[-Index,])%*%
        V_train_r_solve%*%
        (y_train-X_train_r%*%chol2inv(chol(t(X_train_r)%*%V_train_r_solve%*%X_train_r))%*%t(X_train_r)%*%V_train_r_solve%*%y_train)
    
    Error_test[r,s]<-(1/n)*(t(y_test-y_hat_test)%*%(y_test-y_hat_test))
    Error_test_GLS[r,s]<-(1/n)*(t(y_test_Cluster-y_hat_test)%*%(y_test_Cluster-y_hat_test))
    Error_test_LMM[r,s]<-(1/n)*(t(y_test_Cluster-y_hat_test_LMM)%*%(y_test_Cluster-y_hat_test_LMM))
  }
    

    # Last column is given sample_size for some convenience
  
  Error_test[model_no+1,s]<-sample_size[s]
  Error_test_GLS[model_no+1,s]<-sample_size[s]
  Error_test_LMM[model_no+1,s]<-sample_size[s]
  
}


### Some plot

{
    plot( Error_test[-9], type="o", col="red", ylab = 'error' )
    par(new=TRUE)
    plot( Error_test_GLS[-9], type="o", col="green" , ylab = 'error')
    par(new = TRUE)
    plot(Error_test_LMM[-9],type = "o",  col = "blue", ylab = 'error')  
}

par(new = TRUE)
  {
    
    plot( Error_tr[-9], type="o", col="black", ylab = 'error' , main = 'Error Plot')
    par(new = TRUE)
    plot( Error_tr_est[-9], type="o", col="red", ylab = 'error' , main = 'Error Plot')
    par(new=TRUE)
    plot( Error_tr_LMM_est[-9], type="o", col="green", ylab = 'error' )
    par(new = TRUE)
    plot(Error_tr_LMM[-9],type = "l",  col = "blue", ylab = 'error')  
    
}


library(ggplot2)
{
    Error_tr_est_corrected = Error_tr_est + Correction_est
    Error_tr_corrected = Error_tr + Correction
    Error1 = data.frame(Error_tr_est_corrected = Error_tr_est_corrected[-9], Error_tr_est = Error_tr_est[-9], Error_tr = Error_tr[-9], Error_tr_corrected = Error_tr_corrected[-9], Error_test = Error_test[-9], model_no = c(1:8))
    
    col_plot = names(Error1) 
    dlong <- melt(Error1[,c(col_plot)], id.vars="model_no")  
    
    #"value" and "variable" are default output column names of melt()
    ggplot(dlong, aes(x = model_no, value, col=variable)) +
        geom_point() + 
        geom_smooth() +
        ggtitle("Corrected Error without correlation")
        
}




{
    Error_tr_est_GLS_corrected = Error_tr_est + Correction_GLS_est
    Error_tr_corrected = Error_tr + Correction
    Error1 = data.frame(
        Error_tr_est = Error_tr_est [-9], 
        Error_tr_est_GLS_corrected = Error_tr_est_GLS_corrected[-9], 
        Error_tr = Error_tr[-9], 
        Error_tr_corrected = Error_tr_corrected[-9], 
        Error_test = Error_test[-9], 
        model_no = c(1:8))
    
    col_plot = names(Error1) 
    dlong <- melt(Error1[,c(col_plot)], id.vars="model_no")  
    
    #"value" and "variable" are default output column names of melt()
    ggplot(dlong, aes(x = model_no, value, col=variable)) +
        geom_point() + 
        geom_smooth() +
        ggtitle("Corrected Error with correlation using GLM")
        
}

{
    
    plot( Error_test_GLS[-9], type="o", col="red", ylab = 'error' )
    par(new = TRUE)
    
    plot( Error_tr_est[-9] + Correction_GLS_est[-9], type="o", col="green", ylab = 'error' , legend = 'Error Plot')
    par(new = TRUE)
    plot(Error_tr_est[-9],type = "p",  col = "blue", ylab = 'error')  
    par(new = TRUE)
    
    plot( Error_tr[-9], type="o", col="black", ylab = 'error' , main = 'Error Plot')
    par(new=TRUE)
    plot( Error_tr[-9] + Correction_GLS[-9], type="o", col="black", ylab = 'error' , legend = 'Error Plot')
}

{
    
    plot( Error_test_LMM[-9], type="o", col="red", ylab = 'error' )
    par(new = TRUE)
    
    plot( Error_tr_LMM_est[-9] + Correction_LMM_est[-9], type="o", col="green", ylab = 'error' , legend = 'Error Plot')
    par(new = TRUE)
    plot(Error_tr_LMM_est[-9],type = "o",  col = "blue", ylab = 'error')  
    par(new = TRUE)
    
    plot( Error_tr_LMM[-9], type="o", col="black", ylab = 'error' , main = 'Error Plot')
    par(new=TRUE)
    plot( Error_tr_LMM[-9] + Correction_LMM[-9], type="o", col="black", ylab = 'error' , legend = 'Error Plot')
}
    