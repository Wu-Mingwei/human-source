
## predicting the employee turnover data experiment

library(readr)
library(dplyr)
library(tidyverse)
org<-read.csv("org.csv")
glimpse(org)

dim(org)

## Turnover rate = Number of employees who left / Total number of employees


org%>%
  count(status) # see how many employees still be active

org%>%
  summarise(turnover_rate=mean(turnover)) # Since 1 is inactive employee, so the rate is approxmation 18% employees who left.



level<- org%>% #checking the rate of turnover between different level
  group_by(level)%>%
  summarise(turnover_rate=mean(turnover)) ; level

library(ggplot2) #plot the histogram to see the turnover_rate of level
library(broom)
level%>%
  ggplot(aes(level, turnover_rate))+geom_col()


location<- org%>%  # checking the turnover_rate of location
  group_by(location)%>%
  summarise(turnover_rate=mean(turnover)) ;  location

location%>%  #histogram to data visulization
  ggplot(aes(location,turnover_rate))+ geom_col()

org1<-org%>% # first subset the job level in Analyst and Specialist
  filter(level %in% c("Analyst","Specialist"))
dim(org1)

org%>%
  count(level)  # total number for each level
org1%>%
  count(level) #total number between Analyst and Specialist

rating<-read.csv("rating.csv")
dim(rating)

org2 <- left_join(org1,rating, by = "emp_id") # combine two table to see if the rate is effect for turnover

dim(org2)


org2%>%   # calculate the turnover_rate in rating
  group_by(rating)%>%
  summarise(turnover_rate=mean(turnover))


survey<-read.csv("survey.csv")
glimpse(survey)



org3 <- left_join(org2, survey, by = "mgr_id") # combine the table between the org2 and survey
org3%>%
  ggplot(aes(status,mgr_effectiveness))+geom_boxplot() #graph to show if the effectiveness relationship with status

org_final<-read.csv("org_final.csv")
dim(org_final)

org_final%>%
  ggplot(aes(status, distance_from_home))+geom_boxplot() # graph for the relationship between distance from home with status




# Job-hop Index = Total experience / Number of companies


emp_age_diff<-org_final%>%
  mutate(age_diff= mgr_age-emp_age)
emp_age_diff%>%
  ggplot(aes(status,age_diff))+geom_boxplot()

glimpse(emp_age_diff)


emp_JHI<-emp_age_diff%>%
  mutate(jhi=total_experience / no_previous_companies_worked) #calcultate the Job hop for each emplyees from age different
emp_JHI%>%
  ggplot(aes(status,jhi))+geom_boxplot() # box-plot to demonstrate the outliers and mean



library(lubridate) #load package for manipulation the time

emp_tenure<- emp_JHI%>%
  mutate(tenure = ifelse(status=="Active",
                         time_length(interval(date_of_joining, cutoff_date), "years"),
                         time_length(interval(date_of_joining, last_working_date), "years"))) #add column for work duration of employee
emp_tenure%>%
  ggplot(aes(status,tenure))+geom_boxplot() #box plot displaying

emp_tenure%>%
  ggplot(aes(compensation))+geom_histogram() #plot the distribution for compensation

emp_tenure%>%
  ggplot(aes(level, compensation, fill=status))+geom_boxplot() # graph to compare the compensation within status 

# Compa Ratio is estimation to evaluate the employee wage percentage to median pay.
##Compa Ratio = Actual Compensation / Median Compensation 

emp_ratio<- emp_tenure%>%
  group_by(level)%>%
  mutate(median_compensation = median(compensation),
         compa_ratio = (compensation / median_compensation)) # derive compensation ratio
emp_ratio%>%
  distinct(level,median_compensation) # look at the median compensation for each level

emp_final<- emp_ratio%>%
  mutate(emp_level = ifelse( compa_ratio > 1, "Above", "Below")) # add compa level , if compa_ration geater than 1 meaning above, else meaning below
emp_final%>%
  ggplot(aes(status, fill = emp_level))+geom_bar(position = "fill") #compare compa level between active and inactive


# Unstanding information value : measure of predictive power of independent variable to accurately predict the dependent variable
## Information value = sima(% of non-events-% of events))* log( % of non-events/% of events)
##information value : less than 0.15 meaning predictive power is poor, if 0.15 < IV < 0.4 id moderate, else greater than 0.4 meaning strong.

library(Information)
IV <- create_infotables(data = emp_final, y = "turnover") 
IV$Summary  #after we calculate the information value, we can see which variables are significant stronger for predictive power

# split the data 70% into train and 30% into test 


library(ISLR)
smp_siz <- floor(0.7 * nrow(emp_final) )
smp_siz

set.seed(1234)
train_ind<-sample(seq_len(nrow(emp_final)), size = smp_siz)
train <- emp_final [train_ind,]
test<- emp_final [-train_ind,]

train%>%
  count(status)%>%
  mutate(prop=n/sum(n)) #calculate the proportion in train for level and status

test%>%
  count(status)%>%
  mutate(prop=n/sum(n)) # calculate the proportion in test for level and status

log<- glm(turnover ~ percent_hike,
          family= "binomial",
          data=train) # build a logistic regression using percent_hike to predict turnover
summary(log)

mul_log<- glm(turnover~ level+gender+mgr_rating+compensation+hiring_score+marital_status+distance_from_home+monthly_overtime_hrs+work_satisfaction,
              family="binomial",
              data=train) #bulid a multiple regression model for couple independent variables to predict turnover
summary(mul_log)

mul_log1<- glm(turnover~ level+compensation+distance_from_home+monthly_overtime_hrs+work_satisfaction,
               family="binomial",
               data=train)
summary(mul_log1)

#Variance Inflation Factor

library(car)
vif(mul_log1) #check a multicollinearity, the vif for each variables is greater than 1 but less than 2. they are showing the indepent variables moderately correlated

prediction_train<- predict(mul_log1, newdata= train,
                           type = "response")
hist(prediction_train) # distribution skewed left, and histogram shown the probability to the employees who will left organization

prediction_test<-predict(mul_log1 , newdata = test,
                         type = "response")
hist(prediction_test) # check a train data into test data
```

# Turn probabilities in categories by using a cut-off

pre_cut <- ifelse(prediction_test >0.5 , 1 ,0) #classify predictions using a cut-off of 0.5
conf_matrix<- table(pre_cut , test$turnover)
conf_matrix # 1 means inactive while 0 is active

n<-sum(conf_matrix) #number of instances
nc<- nrow(conf_matrix) # number of classes
diag <- diag(conf_matrix) # number of correctly classified instances per class 
rowsums <- apply(conf_matrix, 1, sum) # number of instances per class
colsums <- apply(conf_matrix, 2, sum) # number of predictions per class
p <- rowsums / n # distribution of instances over the actual classes
q <- colsums / n # distribution of instances over the predicted classes



accuracy <- sum(diag) / n ; accuracy # the model's accuracy is 0.88
precision <- diag/colsums;precision # the model's precision to active is 0.97 and inactive 0.53


#create retension strategy

library(tidypredict)
emp_risk<- emp_final %>%
  filter (status == "Active")%>%
  tidypredict_to_column(mul_log1) # calculate probability of turnover and add predictions using the mul_log model

emp_risk %>%
  select(emp_id , fit)%>%
  group_by(level)%>%
  top_n(5, wt = fit)%>%
  arrange(desc(fit))  # look at the employee's probability of turnover from high to low 

emp_risk_bucket <- emp_risk%>%
  mutate(risk_bucket =cut(fit, breaks =c(0,0.3,0.5,0.7,1),
                          labels = c("no-risk", "low-risk", "medium-risk", "high-risk")))
emp_risk_bucket%>%
  count(risk_bucket)%>% #calculate the risk of turnover to the active employee
  group_by(risk_bucket)

#ROI: retun on investment
##ROI = Program Benifits / Program Cost

emp_final%>%
  ggplot(aes(percent_hike))+geom_histogram(binwidth = 3) #plot histogram of percent hike

emp_hike_range<- emp_final%>%
  filter(level == "Analyst")%>%
  mutate(hike_rage = cut(percent_hike, breaks = c(0,10,15,20),
                         include.lowest = TRUE,
                         labels = c("0-10","11-15","16-20"))) #create salary hike_rage of analyst level employees
df_hike<-emp_hike_range%>%
  group_by(hike_rage)%>%
  summarise(turnover_rate_hike = mean(turnover)) # calculate the turnover rate for each salary hike rage

df_hike%>%
  ggplot(aes(hike_rage, turnover_rate_hike))+geom_col()

emp_final%>%
  filter(level == "Analyst")%>%
  count(median_compensation) # after filter we know median_compensation of analyst is 51840

emp_final%>%
  filter(level=="Analyst")%>%
  select(compensation)%>%
  arrange(compensation)%>%
  head()#calculate the minium salary to analyst

extra_cost<- 51840 * 0.05 ; extra_cost #increase the salary 5%
savings <- 40000*0.17 ; savings #assuming the analyst left then hire other one and traning cost

ROI<-(savings / extra_cost)*100
cat(paste0("The return on investment is ", round(ROI), "%!"))