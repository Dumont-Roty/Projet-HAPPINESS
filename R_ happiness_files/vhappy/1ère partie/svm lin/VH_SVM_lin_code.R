####################
# Packages

set.seed(1)
library(wooldridge)
library(tidyverse)
library(tidymodels)
library(discrim)
library(kableExtra)
library(recipes)
library(MASS) #Modélisation LDA/QDA
library(pROC)
library(kknn)
library(doParallel)
library(e1071)

###################
# Importation des données

data("happiness") #base de données


ID_v1 <- happiness[, c(1:13,15:19,21,33)] %>%
  mutate(
    divorce = case_when(
      divorce == "yes" ~ "yes",
      divorce == "no" ~ "no",
      divorce == "iap" ~ "iap",
      is.na(divorce) ~ "NA"
    ),
    widowed = case_when(
      widowed == "yes" ~ "yes",
      widowed == "iap" ~ "iap",
      widowed == "no" ~ "no",
      is.na(widowed) ~ "NA"
    ),
    DivWid = case_when(
      divorce == "yes" | widowed == "yes" ~ "yes",
      divorce == "no" & widowed == "iap" ~ "no",
      TRUE ~ "NA"
    ),
    kids = rowSums(across(c(babies, preteen, teens)), na.rm = TRUE
    ),
    owngun = case_when(
      owngun == "yes" ~ "yes",
      owngun == "iap" ~ "iap",
      owngun == "no" ~ "no",
      is.na(owngun) ~ "NA"
    ),
    vhappy = case_when(
      vhappy == "1" ~ "yes",
      vhappy == "0" ~ "no",
      is.na(vhappy) ~ "NA"
    ),
    unem10 = case_when(
      unem10 == "1" ~ "yes",
      unem10 == "0" ~ "no",
      is.na(unem10) ~ "NA"
    ),
    attend = case_when(
      attend == "never" ~ "0",
      attend == "lt once a year" ~ "0.5",
      attend == "once a year" ~ "1",
      attend == "sevrl times a yr" ~ "6",
      attend == "once a month" ~ "12",
      attend == "2-3x a month" ~ "30",
      attend == "nrly every week" ~ "42",
      attend == "every week" ~ "52",
      attend == "more thn once wk" ~ "104",
      is.na(attend) ~ "NA"
    ),
  ) %>%
  mutate(
    year = as.factor(year),
    workstat = as.factor(workstat),
    prestige = as.numeric(prestige),
    DivWid = as.factor(DivWid),   #
    divorce = as.factor(divorce),
    widowed = as.factor(widowed),
    educ = as.numeric(educ),
    reg16 = as.factor(reg16),
    kids = as.numeric(kids),    #
    #babies = as.numeric(babies),
    #preteen = as.numeric(preteen),
    #teens = as.numeric(teens),
    income = as.factor(income),
    region = as.factor(region),
    attend = as.numeric(attend),
    owngun = as.factor(owngun),
    tvhours = as.numeric(tvhours),
    vhappy = as.factor(vhappy),
    mothfath16 = as.logical(mothfath16),
    black = as.logical(black),
    female = as.logical(female),
    unem10 = as.factor(unem10)
  )

### Divorce / veufs / Enfants / pré-ados / ados

ID_v2 <- ID_v1[,-c(4:5,8:10)]

### imputation de données manquantes de la variable *attend*

n <- nrow(ID_v2) #taille de la data
N <- round(2/3*n) # Taille de l'échantillon d'entrainement
train <- sample(1:n, size = N) # découpage de la data train
dataTrain_att <- ID_v2 %>% slice(train)
dataTest_att <- ID_v2 %>% slice(-train)

rec_att <- recipe(~., data = ID_v2) %>% 
  step_impute_knn(attend, neighbors = 5)

rec_att_prep <- prep(rec_att, training = dataTrain_att)
ID_v3 <- bake(rec_att_prep, new_data = ID_v2)


### Imputation des données manquantes de income

n <- nrow(ID_v3) #taille de la data
N <- round(2/3*n) # Taille de l'échantillon d'entrainement
train <- sample(1:n, size = N) # découpage de la data train
dataTrain_i <- ID_v3 %>% slice(train)
dataTest_i <- ID_v3 %>% slice(-train)

# induce some missing data at random
set.seed(1)

rec_i <- recipe(~ .,data = ID_v3) %>% 
  step_impute_knn(income, neighbors = 5)

rec_i_prep <- prep(rec_i, dataTrain_i)
ID_v4 <- bake(rec_i_prep, new_data = ID_v3)


### imputation de données manquantes de la variable *prestige*

n <- nrow(ID_v4) #taille de la data
N <- round(2/3*n) # Taille de l'échantillon d'entrainement
train <- sample(1:n, size = N) # découpage de la data train
dataTrain_p <- ID_v4 %>% slice(train)
dataTest_p <- ID_v4 %>% slice(-train)

rec_p <- recipe(~., data = ID_v4) %>% 
  step_impute_knn(prestige, neighbors = 5)

rec_p_prep <- prep(rec_p, training = dataTrain_p)
ID_v5 <- bake(rec_p_prep, new_data = ID_v4)


### Nettoyage des valeurs aberrantes

#ID_v5 <- ID_v5[ID_v5$tvhours != 24, ] si aberrant car 4 ont mis + de 24h
# Est ce qu'on retire tout ceux au dessus de 18h ?
# ID_v5 <- ID_v5[ID_v5$babies != 6, ]
# 1 personne à 6 bébé l'autre max est à 4


### imputation de données manquantes de la variable *tvhours*


n <- nrow(ID_v5) #taille de la data
N <- round(2/3*n) # Taille de l'échantillon d'entrainement
train <- sample(1:n, size = N) # découpage de la data train
dataTrain_tv <- ID_v5 %>% slice(train)
dataTest_tv <- ID_v5 %>% slice(-train)

rec_tv <- recipe(~., data = ID_v5) %>% 
  step_impute_knn(tvhours, neighbors = 5)

rec_tv_prep <- prep(rec_tv, training = dataTrain_tv)
ID_v6 <- bake(rec_tv_prep, new_data = ID_v5)

# Suppression des modalités vide
# J'ai supprimé les individus à qui il restait une MDA
ID_v6 <- na.omit(ID_v6)

###########################
#Echantillonage

set.seed(1)
split_dat <- initial_split(ID_v6, prop = 0.75, strata = vhappy) # classique 3 quart / 1 quart
data_train <- training(split_dat)
data_test <- testing(split_dat)

######################
n_core <- parallel::detectCores(logical = TRUE)
registerDoParallel(core = n_core -1)

svm_linear_spec <- svm_poly(degree = 1) |> 
  set_mode("classification") |> 
  set_engine("kernlab")

svm_linear_fit <- svm_linear_spec |> 
 set_args(cost=5) |> 
 fit(vhappy~.,data=ID_v6)

svm_linear_wf <- workflow() |> 
  add_model(svm_linear_fit |> set_args(cost=tune())) |> 
  add_formula(vhappy~.)

data_fold <- vfold_cv(data_train, v=5, strata = vhappy)

svm_grid <- grid_regular(cost(),levels = 5)

tune.res <- tune_grid( 
  svm_linear_wf,
  resamples = data_fold,
  grid = svm_grid
)

autoplot(tune.res)

stopImplicitCluster()

