# frozen_string_literal: true

require 'openssl'
require 'httparty'
require 'json'
require 'active_support/all'


EMAIL = ENV['INPUT_EMAIL']
if EMAIL.blank?
  puts 'INPUT_EMAIL is blank'
  exit 1
end
PASSWORD = ENV['INPUT_PASSWORD']
if PASSWORD.blank?
  puts 'INPUT_PASSWORD is blank'
  exit 1
end
PACKAGE_NAME = ENV['INPUT_PACKAGE_NAME']
if PACKAGE_NAME.blank?
  puts 'INPUT_PACKAGE_NAME is blank'
  exit 1
end
APP_NAME = ENV['INPUT_APP_NAME']
if APP_NAME.blank?
  puts 'INPUT_APP_NAME is blank'
  exit 1
end
PUBLIC_KEY = ENV['INPUT_PUBLIC_KEY']
if PUBLIC_KEY.blank?
  puts 'INPUT_PUBLIC_KEY is blank'
  exit 1
end
APK_FILE_PATH = ENV['INPUT_APK_FILE_PATH']
if APK_FILE_PATH.blank?
  puts 'INPUT_APK_FILE_PATH is blank'
  exit 1
end
UPDATE_DESC = ENV['INPUT_UPDATE_DESC']
if UPDATE_DESC.blank?
  puts 'INPUT_UPDATE_DESC is blank'
  exit 1
end
ONLINE_TIME = ENV['INPUT_ONLINE_TIME']

ONLINE_TIME_FORMAT = '%Y-%m-%d %H:%M:%S'
begin
  Time.strptime(ONLINE_TIME, ONLINE_TIME_FORMAT) unless ONLINE_TIME.blank?
rescue ArgumentError
  puts "INPUT_ONLINE_TIME format error, should be like: #{ONLINE_TIME_FORMAT}"
  exit 1
end

puts "EMAIL: #{EMAIL} PACKAGE_NAME: #{PACKAGE_NAME} APP_NAME: #{APP_NAME} APK_FILE_PATH: #{APK_FILE_PATH} UPDATE_DESC: #{UPDATE_DESC} ONLINE_TIME: #{ONLINE_TIME}"
# 自动发布接口域名
DOMAIN = "http://api.developer.xiaomi.com/devupload"

# 推送普通apk Url前缀
PUSH = "#{DOMAIN}/dev/push"

# 推送渠道包Url前缀
PUSH_CHANNEL_APK = "#{DOMAIN}/dev/pushChannelApk"

# 查询app状态的Url前缀
QUERY = "#{DOMAIN}/dev/query"

# 查询应用分类Url前缀
CATEGORY = "#{DOMAIN}/dev/category"

KEY_SIZE = 1024
GROUP_SIZE = 128
ENCRYPT_GROUP_SIZE = GROUP_SIZE - 11

# 公钥加密函数
def encrypt_by_public_key(param)
  cert = OpenSSL::X509::Certificate.new(PUBLIC_KEY)
  public_key = cert.public_key
  cipher = OpenSSL::PKey::RSA.new(public_key.to_pem)

  text_bytes = param.encode('UTF-8')
  text_bytes_len = text_bytes.length
  idx = 0
  encrypt_bytes = []

  while idx < text_bytes_len
    remain = text_bytes_len - idx
    segsize = remain > ENCRYPT_GROUP_SIZE ? ENCRYPT_GROUP_SIZE : remain
    segment = text_bytes[idx, segsize]
    encrypt_bytes << cipher.public_encrypt(segment)
    idx += segsize
  end

  encrypt_bytes.join.unpack1('H*')
end

# 查询应用信息，前提是小米开放平台已经创建了包名
def query
  request_data = {
    packageName: PACKAGE_NAME,
    userName: EMAIL
  }
  sig = {
    sig: [{
            name: "RequestData",
            hash: Digest::MD5.hexdigest(request_data.to_json)
          }],
    password: PASSWORD
  }
  encrypted_sig = encrypt_by_public_key(sig.to_json)
  HTTParty.post(QUERY, body: { RequestData: request_data.to_json, SIG: encrypted_sig })
end

def push(apk_file, update_desc, sche_online_time)
  online_time = Time.parse(sche_online_time).to_i * 1000
  app_detail = {
    appName: APP_NAME,
    packageName: PACKAGE_NAME,
    updateDesc: update_desc,
  }
  unless sche_online_time.blank?
    app_detail[:onlineTime] = online_time
  end
  request_data = {
    userName: EMAIL,
    appInfo: app_detail.to_json,
    synchroType: 1
  }
  sig_json = {
    sig: [],
    password: PASSWORD
  }
  sig_item = {
    name: "RequestData",
    hash: Digest::MD5.hexdigest(request_data.to_json)
  }
  sig_json[:sig] << sig_item
  if apk_file
    apk = {
      name: "apk",
      hash: Digest::MD5.hexdigest(File.read(apk_file)),
    }
    sig_json[:sig] << apk
  end
  encrypted_sig = encrypt_by_public_key(sig_json.to_json)
  params = {
    RequestData: request_data.to_json,
    SIG: encrypted_sig,
    apk: File.open(apk_file),
  }
  HTTParty.post(PUSH, body: params)
end

resutl = push(APK_FILE_PATH, UPDATE_DESC, ONLINE_TIME)
puts "push result: #{resutl}"