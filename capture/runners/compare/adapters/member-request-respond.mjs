/**
 * Adapter: member-request-respond (page comparison).
 * MemberRequestRespondModal — topLevel RAW modal (own opaque appBackground
 * wash). The twin takes PRE-FORMATTED date/time labels; iOS formats the same
 * epoch itself (fullMonthDayYear "MMMM d, yyyy" + time12Hour "h:mm a"), both
 * in LOCAL tz — so the adapter mirrors those exact formats here.
 */

function labels(epochSeconds) {
  const d = new Date(epochSeconds * 1000);
  return {
    dateLabel: d.toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' }),
    // Some ICU builds emit a narrow no-break space before AM/PM — normalize.
    timeLabel: d
      .toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })
      .replace(/[  ]/g, ' '),
  };
}

export default {
  toClient(shared) {
    const { memberName = '', groupName = '', requestedAt = 1700000000 } = shared ?? {};
    return {
      platform: 'client',
      view: 'pages.leader-twin',
      data: {
        component: 'MemberRequestRespond',
        componentProps: {
          memberName,
          groupName,
          ...labels(requestedAt),
          statusBar: true,
        },
      },
    };
  },

  toIphone(shared) {
    const { memberName = '', groupName = '', requestedAt = 1700000000 } = shared ?? {};
    return {
      platform: 'iphone',
      view: 'pages.member-request-respond',
      auth: {
        isAuthenticated: true,
        currentUser: { id: 'user-1', name: 'Alex Rivera', email: 'alex@example.com', picture: null },
      },
      state: { respond: { memberName, groupName, requestedAt } },
    };
  },
};
