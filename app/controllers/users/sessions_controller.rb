class Users::SessionsController < Devise::SessionsController
  before_filter :authenticate_account, only: [:create]

  protected

  # signs a user in with their email and password
  def authenticate_account
    # authenticate their credentails against sfdc
    sfdc_authentication = Account.new(User.new(:username => params[:user][:username]))
      .authenticate(params[:user][:password])
    # authenticate to sfdc with the admin's access token
    ApiModel.access_token = admin_access_token

    # if they authenticated successfully
    if sfdc_authentication.success.to_bool
      # see if the user exists in the database
      user = User.find_by_username(params[:user][:username])
      if user
        sfdc_account = Account.find(params[:user][:username], 'cloudspokes')
        # update their user records from sfdc
        user.access_token = sfdc_authentication.access_token
        user.sfdc_username = sfdc_account.sfdc_username
        user.email = sfdc_account.email
        user.profile_pic = sfdc_account.profile_pic
        user.accountid = sfdc_account.accountid  
        # save their record, sign them in and redirect
        if user.save
          sign_in_and_redirect(:user, user)
        else
          flash[:alert]  = "Sorry... there was an error logging you in. #{user.errors.full_messages}"
          render action: "new" # sign_in page
        end
      # user exists in sfdc but not in db so create a new record
      else
        sfdc_account = Account.find(params[:user][:username], 'cloudspokes')
        user =  User.new
        # set the sfdc values
        user.access_token = sfdc_authentication.access_token
        user.sfdc_username = sfdc_account.sfdc_username
        user.email = sfdc_account.email
        user.profile_pic = sfdc_account.profile_pic
        user.accountid = sfdc_account.accountid
        user.username = sfdc_account.username
        user.password = params[:user][:password]
        user.skip_confirmation!
        user.create_account

        # save their record, sign them in and redirect
        if user.save
          user.update_attribute(:confirmed_at, DateTime.now)
          sign_in_and_redirect(:user, user)
        else
          flash[:alert]  = "Sorry... there was an error creating your user account. #{user.errors.full_messages}"
          render action: "new" # sign_in page
        end
      end 

    else     
      flash[:alert]  = 'Invalid username / password combination' # sfdc_authentication.message
      render action: "new" # sign_in page
    end

  end

end