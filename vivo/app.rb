# frozen_string_literal: true

require 'openssl'
require 'httparty'
require 'json'
require 'active_support/all'

VIVO_BASE_URL = ENV['INPUT_BASE_URL']
if VIVO_BASE_URL.blank?
  puts 'INPUT_BASE_URL is blank'
  exit 1
end
ACCESS_KEY = ENV['INPUT_ACCESS_KEY']
if ACCESS_KEY.blank?
  puts 'INPUT_ACCESS_KEY is blank'
  exit 1
end
ACCESS_SECRET = ENV['INPUT_ACCESS_SECRET']
if ACCESS_SECRET.blank?
  puts 'INPUT_ACCESS_SECRET is blank'
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
if ONLINE_TIME.blank?
  puts 'INPUT_ONLINE_TIME is blank'
  exit 1
end

ONLINE_TIME_FORMAT = '%Y-%m-%d %H:%M:%S'
begin
  Time.strptime(ONLINE_TIME, ONLINE_TIME_FORMAT)
rescue ArgumentError
  puts "INPUT_ONLINE_TIME format error, should be like: #{ONLINE_TIME_FORMAT}"
  exit 1
end



def common_params
  {
    access_key: ACCESS_KEY,
    timestamp: Time.now.to_i * 1000,
    format: 'json',
    v: '1.0',
    target_app_key: 'developer',
    sign_method: 'HMAC-SHA256'
  }
end

def calSign(params)
  params_map = params.sort.to_h
  params_str = params_map.map { |k, v| "#{k}=#{v}" }.join('&')
  secret_byte = ACCESS_SECRET.encode('UTF-8')
  signing_key = OpenSSL::HMAC.new(secret_byte, OpenSSL::Digest.new('sha256'))
  data_byte = params_str.encode('UTF-8')
  by = signing_key.update(data_byte).digest
  by.unpack1('H*')
end

# 应用APK文件上传
# app.upload.apk.app
# { "code" => 0,
#   "data" => { "packageName" => "com.qixin.mihuas", "versionCode" => "280", "versionName" => "7.16.0-release", "serialnumber" => "457a6770de6fb9b1744b6c9f90fdbaee", "fileMd5" => "21c8b1e3a9891909d7a79c5f9a77c001" },
#   "msg" => "成功",
#   "subCode" => "0",
#   "timestamp" => 1728982450437
# }

def upload_apk_app(apk_file)
  params = common_params
  params[:method] = 'app.upload.apk.app'
  params[:packageName] = 'com.qixin.mihuas'
  params[:fileMd5] = Digest::MD5.file(apk_file).hexdigest
  params[:sign] = calSign(params)
  params[:file] = File.open(apk_file)
  HTTParty.post(VIVO_BASE_URL, body: params)
end

# 应用更新
# app.sync.update.app
def sync_update_app(apk_file, update_desc, sche_online_time)
  params = common_params
  params[:method] = 'app.sync.update.app'
  params[:packageName] = 'com.qixin.mihuas'
  apk_info = upload_apk_app(apk_file)
  params[:versionCode] = apk_info['data']['versionCode']
  params[:apk] = apk_info['data']['serialnumber']
  params[:fileMd5] = apk_info['data']['fileMd5']
  # 1 实时上架 2 定时上架
  params[:onlineType] = 2
  # 上架时间，若onlineType   = 2，上架时间必填。格式：yyyy-MM-dd   HH:mm:ss
  params[:scheOnlineTime] = sche_online_time
  params[:updateDesc] = update_desc
  params[:sign] = calSign(params)
  HTTParty.post(VIVO_BASE_URL, body: params)
end

result = sync_update_app(APK_FILE_PATH, UPDATE_DESC, ONLINE_TIME)
puts "sync_update_app result: #{result}"
