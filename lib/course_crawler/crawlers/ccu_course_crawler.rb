##
# 中正大學課程爬蟲
# 課程資料：https://kiki.ccu.edu.tw/~ccmisp06/Course/zipfiles/
#

require 'rubygems/package'
require 'zlib'
require 'archive/tar/minitar'
require 'fileutils'
require 'open-uri'

module CourseCrawler::Crawlers
class CcuCourseCrawler < CourseCrawler::Base
  include Archive::Tar

  DAYS = {
    "一" => 1,
    "二" => 2,
    "三" => 3,
    "四" => 4,
    "五" => 5,
    "六" => 6,
    "日" => 7,
  }

  # PERIODS = {
  #   "1" => 1,
  #   "2" => 2,
  #   "3" => 3,
  #   "4" => 4,
  #   "5" => 5,
  #   "6" => 6,
  #   "7" => 7,
  #   "8" => 8,
  #   "9" => 9,
  #   "10" => 10,
  #   "11" => 11,
  #   "12" => 12,
  #   "13" => 13,
  #   "14" => 14,
  #   "15" => 15,
  #   "A" => 16,
  #   "B" => 17,
  #   "C" => 18,
  #   "D" => 19,
  #   "E" => 20,
  #   "F" => 21,
  #   "G" => 22,
  #   "H" => 23,
  #   "I" => 24,
  #   "J" => 25
  # }
  PERIODS = CoursePeriod.find('CCU').code_map
  def initialize year: current_year, term: current_term, update_progress: nil, after_each: nil, params: nil

    @year = year || current_year
    @term = term || current_term

    @update_progress_proc = update_progress
    @after_each_proc = after_each

    @download_path = "https://kiki.ccu.edu.tw/~ccmisp06/Course/zipfiles/"
    @filename = "#{@year-1911}#{@term}.tgz"

    @file_path = Rails.root.join('tmp', @filename).to_s
    @dir_name = Rails.root.join('tmp', "#{@year-1911}#{@term}").to_s
  end

  def courses
    @courses = []
    @threads = []
    puts "get url ..."
    # if not Dir.exist?(@dir_name)
      # FileUtils.mkdir_p @dir_name
      File.write(@file_path, open("#{@download_path}#{@filename}", {ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE}).read.force_encoding("utf-8"))

      tgz = Zlib::GzipReader.open(@file_path)
      Minitar.unpack tgz, @dir_name
    # end

    Dir.glob("#{@dir_name}/*.html").reject{|fn| fn.include?('index')}.each do |filename|
      # puts filename
      document = Nokogiri::HTML(File.read(filename).force_encoding('utf-8'))
      if not document.css('h1').text.include?("#{@year-1911}學年度第#{@term}學期")
        []
      else
        department = nil
        document.css('h1').text.match(/系所別\:\ (?<dep>.+)/) {|m| department = m[:dep]}

        document.css('table tr:not(:first-child)').each do |row|
          sleep(1) until (
            @threads.delete_if { |t| !t.status };  # remove dead (ended) threads
            @threads.count < (ENV['MAX_THREADS'] || 20)
          )
          @threads << Thread.new do
            datas = row.css('td')

            code = nil; name = nil; lecturer = nil; credits = nil; required = nil;
            url = nil; times = nil; location = nil; group_code = nil; general_code = nil;
            # 新增 @general_code_count 去區分重複的代碼
            if department == '通識教育中心'
              times =  datas[9] && datas[9].text
              location =  datas[10] && datas[10].text
              group_code = datas[3] && datas[3].text

              code         = datas[3] && "#{@year}-#{@term}-#{datas[2].text}-#{group_code}"
              general_code = "#{datas[2].text}-#{group_code}"
              name         = datas[4] && datas[4].text && datas[4].text.strip
              lecturer     = datas[5] && datas[5].text && datas[5].text.strip
              credits      = datas[7] && datas[7].text && datas[7].text.to_i
              required     = datas[8] && datas[8].text.include?('必')
              url          = datas[12] && datas[12].css('a')[0] && datas[12].css('a')[0][:href]
            else
              times        = datas[8] && datas[8].text
              location     = datas[9] && datas[9].text
              group_code   = datas[2] && datas[2].text

              code         = datas[2] && "#{@year}-#{@term}-#{datas[1].text}-#{group_code}"
              general_code = "#{datas[1].text}-#{group_code}"
              name         = datas[3] && datas[3].text && datas[3].text.strip
              lecturer     = datas[4] && datas[4].text && datas[4].text.strip
              credits      = datas[6] && datas[6].text && datas[6].text.to_i
              required     = datas[7] && datas[7].text.include?('必')
              url          = datas[11] && datas[11].css('a')[0] && datas[11].css('a')[0][:href]
            end

            course_days = []
            course_periods = []
            course_locations = []

            if times && location
              times.split(' ').each do |time|
                time.match(/(?<d>[#{DAYS.keys.join}])(?<p>.+)/) do |m|
                  m[:p].split(',').each do |period|
                    course_days << DAYS[m[:d]]
                    course_periods << PERIODS[period]
                    course_locations << location
                  end
                end
              end
            end
            puts "data crawled : " + name
            course = {
              year: @year,
              term: @term,
              code: code,
              general_code: general_code,
              group_code: group_code,
              name: name,
              lecturer: lecturer,
              department: department,
              credits: credits,
              required: required,
              url: url,
              day_1: course_days[0],
              day_2: course_days[1],
              day_3: course_days[2],
              day_4: course_days[3],
              day_5: course_days[4],
              day_6: course_days[5],
              day_7: course_days[6],
              day_8: course_days[7],
              day_9: course_days[8],
              period_1: course_periods[0],
              period_2: course_periods[1],
              period_3: course_periods[2],
              period_4: course_periods[3],
              period_5: course_periods[4],
              period_6: course_periods[5],
              period_7: course_periods[6],
              period_8: course_periods[7],
              period_9: course_periods[8],
              location_1: course_locations[0],
              location_2: course_locations[1],
              location_3: course_locations[2],
              location_4: course_locations[3],
              location_5: course_locations[4],
              location_6: course_locations[5],
              location_7: course_locations[6],
              location_8: course_locations[7],
              location_9: course_locations[8],
              note: datas[13] && datas[13].text,
            }

            @after_each_proc.call(course: course) if @after_each_proc
            @courses << course
            # if not document.css('h1').text.include?('系所別: 通識教育中心')
            #   course[:grade] = datas[0] && datas[0].text
            #   course[:type] = datas[10] && datas[10].text
            # end

          end # end Thread
        end # document.css('table tr:not(:first-child)').map
      end # if not document.css('h1').text.include?
    end # .inject { |arr, nxt| arr.concat nxt }
    ThreadsWait.all_waits(*@threads)
    puts "Project finished !!!"
    @courses
  end
end
end
