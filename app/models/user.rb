require 'digest/sha1'

class User < ActiveRecord::Base
  has_many :actions
  
  include Authentication
  include Authentication::ByPassword
  include Authentication::ByCookieToken
  include Authorization::StatefulRoles
  validates_presence_of     :login
  validates_length_of       :login,    :within => 3..40
  validates_uniqueness_of   :login
  validates_format_of       :login,    :with => Authentication.login_regex, :message => Authentication.bad_login_message

  validates_format_of       :firstname,     :with => Authentication.name_regex,  :message => Authentication.bad_name_message
  validates_length_of       :firstname,     :within => 2..100
  validates_format_of       :lastname,      :with => Authentication.name_regex,  :message => Authentication.bad_name_message
  validates_length_of       :lastname,      :within => 2..100

  validates_presence_of     :email
  validates_length_of       :email,    :within => 6..100 #r@a.wk
  validates_uniqueness_of   :email
  validates_format_of       :email,    :with => Authentication.email_regex, :message => Authentication.bad_email_message

  
  attr_accessor :terms_of_service
  validates_acceptance_of :terms_of_service

  # HACK HACK HACK -- how to do attr_accessible from here?
  # prevents a user from submitting a crafted form that bypasses activation
  # anything else you want your user to change should be added here.
  attr_accessible :login, :email, :firstname, :lastname, :password, :password_confirmation, :newsletter, :terms_of_service #:phone



  # Authenticates a user by their login name and unencrypted password.  Returns the user or nil.
  #
  # uff.  this is really an authorization, not authentication routine.  
  # We really need a Dispatch Chain here or something.
  # This will also let us return a human error message.
  #
  def self.authenticate(login, password)
    return nil if login.blank? || password.blank?
    u = find_in_state :first, :active, :conditions => {:login => login} # need to get the salt
    u && u.authenticated?(password) ? u : nil
  end

  def login=(value)
    write_attribute :login, (value ? value.downcase : nil)
  end

  def email=(value)
    write_attribute :email, (value ? value.downcase : nil)
  end

  def forgot_password
    @forgotten_password = true
    self.make_password_reset_code
  end
  
  def reset_password
    # First update the password_reset_code before setting the
    # reset_password flag to avoid duplicate email notifications.
    update_attribute(:password_reset_code, nil)
    @reset_password = true
  end
  
  # used in user_observer
  def recently_forgot_password?
    @forgotten_password
  end
  
  def recently_reset_password?
    @reset_password
  end  
  
  def self.find_for_forget(email)
    find :first, :conditions => ['email = ? and activated_at IS NOT NULL', email]
  end

  
  
  protected
    
    def make_activation_code
        self.deleted_at = nil
        self.activation_code = self.class.make_token
    end

    def make_password_reset_code
        self.password_reset_code = self.class.make_token #Digest::SHA1.hexdigest( Time.now.to_s.split(//).sort_by {rand}.join )
    end
end
