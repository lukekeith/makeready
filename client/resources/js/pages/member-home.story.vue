<script setup lang="ts">
import '../../css/app.scss'
import NavigationIsland from '../components/domain/navigation-island/navigation-island.vue'
</script>

<template>
  <Story title="Pages/Member Home" group="pages">
    <Variant title="With Groups">
      <div class="MemberHomePage">
        <div class="MemberHomePage__content">
          <div class="MemberHomePage__groups-list">
            <a href="#" class="MemberHomePage__group-link">
              <div class="GroupCard GroupCard--default GroupCard--with-cover GroupCard--with-chevron">
                <img src="https://picsum.photos/seed/group1/440/200" alt="Young Professionals" class="GroupCard__cover-image" />
                <div class="GroupCard__gradient"></div>
                <div class="GroupCard__top"></div>
                <div class="GroupCard__bottom">
                  <h3 class="GroupCard__title">Young Professionals</h3>
                  <p class="GroupCard__joined">
                    <span class="GroupCard__joined-label">Member since </span>
                    <span class="GroupCard__joined-date">March 18, 2026</span>
                  </p>
                  <div class="GroupCard__details">
                    <div class="GroupCard__detail">
                      <svg width="20" height="20" viewBox="0 0 24 24" fill="none"><rect x="3" y="11" width="18" height="11" rx="2" stroke="white" stroke-width="2"/><path d="M7 11V7C7 4.23858 9.23858 2 12 2C14.0503 2 15.8124 3.2341 16.584 5" stroke="white" stroke-width="2" stroke-linecap="round"/></svg>
                      <span>Public group</span>
                    </div>
                    <div class="GroupCard__detail">
                      <span class="GroupCard__member-count">5</span>
                      <span>members</span>
                    </div>
                  </div>
                </div>
                <div class="GroupCard__chevron">
                  <svg width="24" height="24" viewBox="0 0 24 24" fill="none"><path d="M9 18L15 12L9 6" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
                </div>
              </div>
            </a>
          </div>
        </div>

        <div class="MemberHomePage__navigation-container">
          <NavigationIsland selected="home" initials="LK" homeHref="#" profileHref="#" memberName="Luke Keith" memberPhone="+12145551234" logoutUrl="#" csrfToken="test" />
        </div>
      </div>
    </Variant>

    <Variant title="Empty State">
      <div class="MemberHomePage">
        <div class="MemberHomePage__content">
          <div class="MemberHomePage__groups-list">
            <div class="MemberHomePage__empty-state">
              <p class="MemberHomePage__empty-title">No groups yet</p>
              <p class="MemberHomePage__empty-description">Join a group to get started with your journey.</p>
            </div>
          </div>
        </div>

        <div class="MemberHomePage__navigation-container">
          <NavigationIsland selected="home" initials="LK" homeHref="#" profileHref="#" memberName="Luke Keith" logoutUrl="#" csrfToken="test" />
        </div>
      </div>
    </Variant>
  </Story>
</template>
