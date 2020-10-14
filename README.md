# iotterraform
This script will help you deploy a complete IoT scenario in Azure

This is a very simple Terraform Script that will create the following resources:
  1) IoT Hub (with two endpoints and two routes)
  2) Storage Account (this is one of the endpoints where we will route the information from IoT)
  3) Event Hub (this is another endpoint for message routing)
  4) Stream Analytics to process streaming information
  5) ADLS to have a data lake for the solution
  6) Azure Function that will help on adding logic to the processing of data
 
The architecture will look line this:

<IMAGE.TODO.JPEG>
