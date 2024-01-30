import requests,os,bs4
#from telebot import *
#import telebot#
import random
import os
from telebot import *

auth='6974767086:AAFGuDV-aO17RbP8ytohYcN3z2wZXcNHsMk'
msg=''

def extract_arg(arg):
    return arg.split()

# telebot import *
bot = telebot.TeleBot(auth) 
# creating a instance
@bot.message_handler(commands=["start"])
def strt(message):
  bot.reply_to(message, 'starting bot awakened /help to know usage')
  


@bot.message_handler(commands = ['help'])
def xk(message):
  bot.reply_to(message, ' for sending anonymous message \n usage ::: \n /send country_code num \n ex : /send 91 80790##### \n in this way')
  

@bot.message_handler(commands = ['send'])
def sn(message):
  global country
  global num
  a=extract_arg(message.text)
  num=int(a[2])
  country=int(a[1].strip('+'))
  
  bot.reply_to(message,'now send message \n example : /msg hi hlw welcome thank you , love you ...')

@bot.message_handler(commands = ['msg'])
def m(message):
  os.system('echo "" > zx.txt')
  bot.reply_to(message,f'sending to {country} {num}')
  msg=extract_arg(message.text)[1::]
  
  os.system(f'python3 anon_sms.py {country} {num} {msg}')
  time.sleep(3)
  o=open('zx.txt','r')
  bot.reply_to(message,str(o.read()))

bot.infinity_polling()
