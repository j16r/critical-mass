require 'spec_helper'

describe 'The lobby', :type => :request do

  before do
    visit '/'
  end

  context 'logging in' do

    context 'empty nickname' do

      it 'cannot login' do
        fill_in 'Nickname', :with => ''
        click_on 'submit'
        page.should have_css('#login')
      end

    end

    context 'valid nickname' do

      let(:player1_nickname) { 'Stalin' }

      it 'can login' do
        fill_in 'Nickname', :with => player1_nickname
        click_on 'submit'
        page.should have_css('#currentUser', :text => player1_nickname)
      end

    end

  end

  context 'sending messages' do

    let(:player1_nickname) { 'Tolstoy' }
    let(:player2_nickname) { 'Churchill' }

  end

  context 'creating games' do

  end

end
