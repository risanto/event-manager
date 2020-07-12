require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

def clean_zipcode(zipcode)
    zipcode = zipcode.to_s.rjust(5, "0")[0..4]
end

def chunk_phone(phone)
    result = ''
    arr = phone.scan(/.{1,3}/)

    for i in 0..arr.length-1 do
        if i == arr.length-2
            result += arr[i] + arr[i+1]
            break
        else
            result += arr[i] + '-'
        end
    end

    result
end

def clean_phone_number(phone)
    phone = phone.scan(/\d/).join('')

    if (phone.length < 10) || (
        phone.length > 10 && phone[0] != '1'
        ) || (phone.length > 11)
        "#{chunk_phone(phone)} (bad number, please update us with a correct number to receive mobile alerts)"
    elsif phone.length == 11 && phone[0] == '1'
        chunk_phone(phone[1..10])
    elsif phone.length == 10
        chunk_phone(phone)
    end
end

def legislators_by_zipcode(zip)
    civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
    civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

    begin
        legislators = civic_info.representative_info_by_address(
        address: zip,
        levels: 'country',
        roles: ['legislatorUpperBody', 'legislatorLowerBody']
        ).officials
    rescue
        "You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials"
    end
end

def save_thank_you_letter(id, form_letter)
    Dir.mkdir("output") unless Dir.exists? "output"

    filename = "output/thanks_#{id}.html"

    File.open(filename, 'w') do |file|
        file.puts form_letter
    end
end

puts "EventManager initialised!"

contents = CSV.open "event_attendees.csv", headers: true, header_converters: :symbol

template_letter = File.read "form_letter.erb"
erb_template = ERB.new template_letter

datetime_arr = []

contents.each do |row|
    id = row[0]
    name = row[:first_name]

    date_time = DateTime.strptime(row[:regdate], '%Y/%d/%m %H:%M')
    datetime_arr << date_time

    phone = clean_phone_number(row[:homephone])
    zipcode = clean_zipcode(row[:zipcode])
    legislators = legislators_by_zipcode(zipcode)

    form_letter = erb_template.result(binding)

    # Create a personalised thank you letters for event attendes -> html files stored in output

    # save_thank_you_letter(id, form_letter)
end


def time_targeting(datetime_arr, target_by)
    result = Hash.new(0)

    datetime_arr.each do |date|
        if (target_by == 'hour')
            result["#{date.hour}:00"] += 1
        elsif (target_by == 'day')
            days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']
            result[days[date.wday]] += 1
        end
    end

    result.sort_by {|k, v| -v}
end


# Time targeting to see which hours of the day the most people registered

hour_targets = time_targeting(datetime_arr, 'hour')

hour_targeting = File.read "hour_targeting.erb"
hour_targeting_tab = ERB.new hour_targeting

def save_table(tab, tab_name)
    Dir.mkdir("output") unless Dir.exists? "output"

    filename = "output/#{tab_name}.html"

    File.open(filename, 'w') do |file|
        file.puts tab.result
    end
end

save_table(hour_targeting_tab, 'hour_targeting')


# Time targeting to see which day of the week most people registered

# pp time_targeting(datetime_arr, 'day')