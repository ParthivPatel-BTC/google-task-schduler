class TasksController < ApplicationController
  require "google/apis/calendar_v3"
  require "google/api_client/client_secrets.rb"
  before_action :set_task, only: [:show, :edit, :update, :destroy]

  CALENDAR_ID = 'primary'
  # GET /tasks
  # GET /tasks.json
  def index
    @tasks = Task.all
  end

  # GET /tasks/1
  # GET /tasks/1.json
  def show
  end

  # GET /tasks/new
  def new
    @task = Task.new
  end

  def edit(task, user)
    client = get_google_calendar_client user
    event = get_event task
    event = Google::Apis::CalendarV3::Event.new(event)
    client.update_event(CALENDAR_ID, event.id, event)
  end

  def create
    client = get_google_calendar_client current_user
    task = params[:task]
    event = get_event task
    # event = Google::Apis::CalendarV3::Event.new(event)
    client.insert_event('primary', event)
    flash[:notice] = 'Task was successfully added.'
    # task[:user_id] = current_user.id
    # task.save!
  end

  # PATCH/PUT /tasks/1
  # PATCH/PUT /tasks/1.json
  def update
    respond_to do |format|
      if @task.update(task_params)
        format.html { redirect_to @task, notice: 'Task was successfully updated.' }
        format.json { render :show, status: :ok, location: @task }
      else
        format.html { render :edit }
        format.json { render json: @task.errors, status: :unprocessable_entity }
      end
    end
  end

  def delete(event_id, user)
    client = get_google_calendar_client user
    client.delete_event(CALENDAR_ID, event_id)
  end

  def get(event_id, user)
    client = get_google_calendar_client user
    client.get_event(CALENDAR_ID, event_id)
  end

  def get_google_calendar_client current_user
      client = Google::Apis::CalendarV3::CalendarService.new
      return unless (current_user.present? && current_user.access_token.present? && current_user.refresh_token.present?)
      secrets = Google::APIClient::ClientSecrets.new({
        "web" => {
          "access_token" => current_user.access_token,
          "refresh_token" => current_user.refresh_token,
          "client_id" => '602766909053-k7tjqs8dnioeluhb92sku2ebtdil8f7g.apps.googleusercontent.com',
          "client_secret" => 'Rgka_C7NsLuPhx-XgTq4muwD'
        }
      })
      begin
        client.authorization = secrets.to_authorization
        client.authorization.grant_type = "refresh_token"

        if !current_user.present?
          client.authorization.refresh!
          current_user.update_attributes(
            access_token: client.authorization.access_token,
            refresh_token: client.authorization.refresh_token,
            expires_at: client.authorization.expires_at.to_i
          )
        end
      rescue => e
        flash[:error] = 'Your token has been expired. Please login again with google.'
        redirect_to :back
      end
      client
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_task
      @task = Task.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def task_params
      params.require(:task).permit(:title, :description, :start_date, :end_date, :event, :members, :user_id)
    end


    def get_event task
      attendees = task[:members].split(',').map{ |t| {email: t.strip} }
      event = Google::Apis::CalendarV3::Event.new({
        summary: task[:title],
        location: '800 Howard St., San Francisco, CA 94103',
        description: task[:description],
        start: {
          date_time: Time.new(task['start_date(1i)'],task['start_date(2i)'],task['start_date(3i)'],task['start_date(4i)'],task['start_date(5i)']).to_datetime.rfc3339,
          time_zone: "Asia/Kolkata"
          # date_time: '2019-09-07T09:00:00-07:00',
          # time_zone: 'Asia/Kolkata',
        },
        end: {
          date_time: Time.new(task['end_date(1i)'],task['end_date(2i)'],task['end_date(3i)'],task['end_date(4i)'],task['end_date(5i)']).to_datetime.rfc3339,
          time_zone: "Asia/Kolkata"
        },
        attendees: attendees,
        reminders: {
          use_default: false,
          overrides: [
            Google::Apis::CalendarV3::EventReminder.new(reminder_method:"popup", minutes: 10),
            Google::Apis::CalendarV3::EventReminder.new(reminder_method:"email", minutes: 20)
          ]
        },
        notification_settings: {
          notifications: [
                          {type: 'event_creation', method: 'email'},
                          {type: 'event_change', method: 'email'},
                          {type: 'event_cancellation', method: 'email'},
                          {type: 'event_response', method: 'email'}
                         ]
        }, 'primary': true
      })

    # def get_event task
    #   attendees = task[:members].split(',').map{ |t| {email: t.strip} }
    #   binding.pry
    #   event = Google::Apis::CalendarV3::Event.new({
    #     summary: task[:title],
    #     location: '800 Howard St., San Francisco, CA 94103',
    #     description: task[:description],
    #     start: {
    #       date_time: '2019-09-07T09:00:00-07:00',
    #       time_zone: 'Asia/Kolkata',
    #     },
    #     end: {
    #       date_time: '2019-09-07T17:00:00-07:00',
    #       time_zone: 'Asia/Kolkata',
    #     },
    #     attendees: attendees,
    #     reminders: {
    #       use_default: false
    #     },
    #   })

# event = {'summary' => "#{params[:event][:summary]}",
#          'location' => "#{params[:event][:location]}",
#          'start' => { 'dateTime' => Time.new(task['start_date(1i)'],
#                                              task['start_date(2i)'],
#                                              task['start_date(3i)'],
#                                              task['start_date(4i)'],
#                                              task['start_date(5i)'])
#                                         .to_datetime.rfc3339,
#                       'timeZone' => "America/Denver" },
#          'end' => { 'dateTime' => Time.new(params['event']['end_time(1i)'],
#                                            params['event']['end_time(2i)'],
#                                            params['event']['end_time(3i)'],
#                                            params['event']['end_time(4i)'],
#                                            params['event']['end_time(5i)'])
#                                       .to_datetime.rfc3339,
#                     'timeZone' => "America/Denver" }}
      # event = Google::Apis::CalendarV3::Event.new({
      #   start: Google::Apis::CalendarV3::EventDateTime.new(date: today),
      #   end: Google::Apis::CalendarV3::EventDateTime.new(date: today + 1),
      #   summary: task[:title],
      #   description: task[:description],
      #   attendees: ['parthiv.patel@botreetechnologies.com']
      # })
      # event = Google::Apis::CalendarV3::Event.new({
      #   'summary':'Google I/O 2015',
      #   'location':'800 Howard St., San Francisco, CA 94103',
      #   'description':'A chance to hear more about Google\'s developer products.',
      #   'start':{
      #     'date_time': DateTime.parse('2016-05-28T09:00:00-07:00'),
      #     'time_zone': 'America/Los_Angeles'
      #   },
      #   'end':{
      #     'date_time': DateTime.parse('2016-05-28T17:00:00-07:00'),
      #     'time_zone': 'America/Los_Angeles'
      #   }
      # }) 

      #event[:id] = task[:event] if task[:event]
    end
end
