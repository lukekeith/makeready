<script setup lang="ts">
import '../../css/app.scss'
import NavigationIsland from '../components/domain/navigation-island/navigation-island.vue'
</script>

<template>
  <Story title="Pages/Group Home" group="pages">
    <Variant title="With Study + Post">
      <div class="GroupHome">
        <div class="GroupHome__viewport">
          <div class="GroupHome__scroll-container">
            <!-- Group Header Card -->
            <div class="GroupCard GroupCard--header GroupCard--with-cover">
              <img src="https://picsum.photos/seed/yp/440/300" alt="Young Professionals" class="GroupCard__cover-image" />
              <div class="GroupCard__gradient"></div>
              <div class="GroupCard__top">
                <button class="GroupCard__back-button" aria-label="Go back">
                  <svg width="24" height="24" viewBox="0 0 24 24" fill="none"><path d="M15 18L9 12L15 6" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
                </button>
              </div>
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
            </div>

            <!-- Study Section -->
            <div class="GroupHome__studies CardParent">
              <div class="StudyCard StudyCard--progress CardChild" role="button" tabindex="0">
                <div class="StudyCard__content">
                  <div class="StudyCard__date">
                    <span class="StudyCard__label">DAY</span>
                    <span class="StudyCard__day">31</span>
                  </div>
                  <div class="StudyCard__details StudyCard__details--progress">
                    <div class="StudyCard__title-section">
                      <h4 class="StudyCard__title">Romans in 30 days</h4>
                      <p class="StudyCard__description">A deep dive on the book of Romans</p>
                    </div>
                    <div class="StudyCard__progress-bar">
                      <div class="StudyCard__progress-fill" style="width: 25%"></div>
                    </div>
                  </div>
                </div>
              </div>

              <div class="StudyCard StudyCard--lesson-list CardChild" role="button" tabindex="0">
                <div class="StudyCard__content">
                  <div class="StudyCard__date">
                    <span class="StudyCard__label StudyCard__label--active">DAY</span>
                    <span class="StudyCard__day">1</span>
                  </div>
                  <div class="StudyCard__details StudyCard__details--lesson-list">
                    <div class="StudyCard__status-badge StudyCard__status-badge--next">
                      <span class="StudyCard__status-text">Next</span>
                    </div>
                    <div class="StudyCard__title-section">
                      <h4 class="StudyCard__title">Exodus 12:13-15</h4>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <!-- Posts -->
            <div class="GroupHome__posts">
              <div class="GroupPostCard GroupPostCard--welcome">
                <div class="GroupPostCard__author-row">
                  <div class="GroupPostCard__avatar">
                    <img src="https://i.pravatar.cc/48?img=3" alt="Leader" />
                  </div>
                  <div class="GroupPostCard__author-info">
                    <span class="GroupPostCard__author-name">MakeReady</span>
                    <div class="GroupPostCard__timestamp">
                      <span class="GroupPostCard__timestamp-value">20</span>
                      <span class="GroupPostCard__timestamp-unit">days ago</span>
                    </div>
                  </div>
                </div>
                <p class="GroupPostCard__content">Young Professionals is beginning the Romans in 30 days study program! Get ready for 31 days of growth together!</p>
                <img src="https://picsum.photos/seed/study/440/200" alt="Post" class="GroupPostCard__post-image" />
              </div>
            </div>

            <div class="GroupHome__bottom-spacer"></div>
          </div>

          <div class="GroupHome__navigation">
            <NavigationIsland selected="home" initials="LK" avatarUrl="https://i.pravatar.cc/48?img=3" homeHref="#" profileHref="#" memberName="Luke Keith" memberPhone="+12145551234" logoutUrl="#" csrfToken="test" />
          </div>
        </div>
      </div>
    </Variant>
  </Story>
</template>
