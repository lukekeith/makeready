@extends('layouts.marketing')

@section('title', 'Beta application — MakeReady')
@section('description', 'Complete your MakeReady beta application.')

@section('content')
<main class="MarketingPage MarketingPage--narrow">
    <section class="MarketingFormShell">
        <div class="MarketingFormShell__intro">
            <h5 class="Eyebrow">Beta application</h5>
            <h1>Help us understand your group.</h1>
            @if(!empty($googleUser['email']))
                <p>Signed in as <strong>{{ $googleUser['email'] }}</strong>. This identity will be attached to your application.</p>
            @endif
        </div>

        @if($errors->any())
            <div class="MarketingFormError" role="alert">
                @foreach($errors->all() as $error)
                    <p>{{ $error }}</p>
                @endforeach
            </div>
        @endif

        <form class="MarketingForm" method="POST" action="/join-beta/application">
            @csrf
            <x-marketing.text-input
                name="organizationName"
                label="Organization name"
                placeholder="Your church, school, or group name"
                :value="old('organizationName')"
                :required="true"
                :maxlength="200"
                autocomplete="organization"
            />
            <x-marketing.text-input
                name="organizationWebsite"
                label="Organization website"
                placeholder="https://example.org"
                :value="old('organizationWebsite')"
                :optional="true"
                type="url"
                :maxlength="500"
            />
            <x-marketing.text-input
                name="phoneNumber"
                label="Phone number"
                :value="old('phoneNumber')"
                :optional="true"
                :maxlength="40"
                autocomplete="tel"
            />
            <x-marketing.text-input
                name="groupMemberAgeRange"
                label="Group member age range"
                placeholder="Adults, college students, high school, mixed ages..."
                :value="old('groupMemberAgeRange')"
                :required="true"
                :maxlength="120"
            />
            <div class="MarketingForm__row">
                <x-marketing.text-input
                    name="numberOfGroups"
                    label="Number of groups managed"
                    :value="old('numberOfGroups', 1)"
                    :required="true"
                    type="number"
                    :min="1"
                    :max="500"
                />
                <x-marketing.text-input
                    name="estimatedGroupMembers"
                    label="Estimated group members"
                    :value="old('estimatedGroupMembers')"
                    :required="true"
                    type="number"
                    :min="1"
                    :max="100000"
                />
            </div>
            <x-marketing.text-input
                name="groupDescription"
                label="Describe the group or groups you lead"
                placeholder="Who do you lead, what kind of growth or study rhythm do you want to support, and why is now a good time for MakeReady?"
                :value="old('groupDescription')"
                :required="true"
                :multiline="true"
                :rows="6"
                :minlength="20"
                :maxlength="5000"
            />
            <button class="MarketingButton MarketingButton--primary" type="submit">Submit beta application</button>
        </form>
    </section>
</main>
@endsection
