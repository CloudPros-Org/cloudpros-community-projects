#base image using python 3.13-alpine
FROM python:3.13-alpine 
#set the working directory to /app
WORKDIR /app 
ENV  PYTHONDONTWRITEBYTECODE=1   
#prevent Python from buffering stdout and stderr
ENV  PYTHONUNBUFFERED=1  
#copy requirements.txt to the working directory
COPY requirements.txt . 
#install the dependencies from requirements.txt
RUN pip --no-cache-dir install -r requirements.txt
#copy the files in the local app folder to workdir 
COPY app .
#open ports 8000 internally and externally for the container    
EXPOSE 8000 
#run the uvicorn server with hot reloading
CMD ["python", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"] 