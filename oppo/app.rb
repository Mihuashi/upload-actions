# frozen_string_literal: true

require 'openssl'
require 'httparty'
require 'json'
require 'active_support/all'

OPPO_BASE_URL = 'https://oop-openapi-cn.heytapmobi.com'

CLIENT_ID = ENV['INPUT_CLIENT_ID']
if CLIENT_ID.blank?
  puts 'INPUT_CLIENT_ID is blank'
  exit 1
end
CLIENT_SECRET = ENV['INPUT_CLIENT_SECRET']
if CLIENT_SECRET.blank?
  puts 'INPUT_CLIENT_SECRET is blank'
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
VERSION_CODE = ENV['INPUT_VERSION_CODE']
if VERSION_CODE.blank?
  puts 'INPUT_VERSION_CODE is blank'
  exit 1
end
puts "CLIENT_ID: #{CLIENT_ID} APK_FILE_PATH: #{APK_FILE_PATH} UPDATE_DESC: #{UPDATE_DESC} ONLINE_TIME: #{ONLINE_TIME} VERSION_CODE: #{VERSION_CODE}"

def get_access_token
  return @access_token if @access_token

  url = "#{OPPO_BASE_URL}/developer/v1/token"
  params = {
    client_id: CLIENT_ID,
    client_secret: CLIENT_SECRET
  }
  response = HTTParty.get(url, query: params)
  @access_token = response['data']['access_token']
end

def common_params
  {
    access_token: get_access_token,
    timestamp: Time.now.to_i
  }
end

# api 签名
def sign(params)
  params_map = params.sort.to_h
  params_str = params_map.map { |k, v| "#{k}=#{v}" }.join('&')
  secret_byte = CLIENT_SECRET.encode('UTF-8')
  signing_key = OpenSSL::HMAC.new(secret_byte, OpenSSL::Digest.new('sha256'))
  data_byte = params_str.encode('UTF-8')
  by = signing_key.update(data_byte).digest
  params[:api_sign] = by.unpack1('H*')
  params
end

# 查询普通包详情
def get_app_info
  url = "#{OPPO_BASE_URL}/resource/v1/app/info"
  params = common_params
  params[:pkg_name] = 'com.qixin.mihuas'
  params = sign(params)
  HTTParty.get(url, query: params)
end

def get_upload_url
  url = "#{OPPO_BASE_URL}/resource/v1/upload/get-upload-url"
  params = common_params
  params = sign(params)
  response = HTTParty.get(url, query: params)
  #   {"errno"=>0, "data"=>{"upload_url"=>"https://api.open.oppomobile.com/api/utility/upload", "sign"=>"fa80c5151cb9db7abd1b7183c68f1588"}}
  [response['data']['upload_url'], response['data']['sign']]
end

# 文件上传
# {
#   "errno":0,
#   "data":{
#     "url":"http://storedl1.nearme.com.cn/apk/tmp_apk/202410/15/3a3636314843e42001b91c8d627c5520.apk",
#     "uri_path":"/apk/tmp_apk/202410/15/3a3636314843e42001b91c8d627c5520.apk",
#     "md5":"21c8b1e3a9891909d7a79c5f9a77c001",
#     "file_size":137721633,
#     "file_extension":"apk",
#     "width":0,
#     "height":0,
#     "id":"526ab5d5-b2ef-4e75-9dfd-c5f497154275",
#     "sign":"6aa49c4d2b198fa7e56bc88372728200"
#   },
#   "logid":"526ab5d5-b2ef-4e75-9dfd-c5f497154275"
# }
def upload_file(apk_file)
  upload_url, sign = get_upload_url
  params = common_params
  params[:sign] = sign
  params[:type] = 'apk'
  params = sign(params)
  params[:file] = File.open(apk_file)
  HTTParty.post(upload_url, body: params)
end

# 发布版本
def update_app_info(apk_file, update_desc, sche_online_time, version_code)
  # {"errno"=>0, "data"=>{"success"=>true, "message"=>"发布版本、更新资料接口近期有更新，请您尽快配置新增必填参数、删减无需传递的参数，避免后续影响应用更新！详情请查看https://open.oppomobile.com/new/dev"}}
  url = "#{OPPO_BASE_URL}/resource/v1/app/upd"
  apk_info = upload_file(apk_file)
  app_info = get_app_info
  params = common_params
  params[:pkg_name] = 'com.qixin.mihuas'
  params[:version_code] = version_code
  params[:apk_url] = [{
                        url: apk_info['data']['url'],
                        md5: apk_info['data']['md5'],
                        cpu_code: 0
                      }].to_json
  params[:app_name] = app_info['data']['app_name']
  params[:second_category_id] = app_info['data']['second_category_id']
  params[:third_category_id] = app_info['data']['third_category_id']
  params[:summary] = app_info['data']['summary']
  params[:detail_desc] = app_info['data']['detail_desc']
  params[:update_desc] = update_desc
  params[:privacy_source_url] = app_info['data']['privacy_source_url']
  params[:icon_url] = app_info['data']['icon_url']
  params[:pic_url] = app_info['data']['pic_url']
  params[:test_desc] = app_info['data']['test_desc']
  params[:copyright_url] = app_info['data']['copyright_url']
  params[:business_username] = app_info['data']['business_username']
  params[:business_email] = app_info['data']['business_email']
  params[:business_mobile] = app_info['data']['business_mobile']
  params[:age_level] = app_info['data']['age_level']
  params[:adaptive_equipment] = app_info['data']['adaptive_equipment']
  params[:online_type] = sche_online_time.blank? ? 1 : 2
  unless sche_online_time.blank?
    params[:sche_online_time] = sche_online_time
  end
  params = sign(params)
  HTTParty.post(url, body: params)
end

result = update_app_info(APK_FILE_PATH, UPDATE_DESC, ONLINE_TIME, VERSION_CODE)
puts "update_app_info result: #{result}"