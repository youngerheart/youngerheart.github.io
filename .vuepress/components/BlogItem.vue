<template>
  <div class="blogitem">
    <div class="title">
      <a :href="page.regularPath">{{ page.frontmatter.title }}</a>
      <span>{{ dayjs(page.frontmatter.date).format('YY-MM-DD') }}</span>
    </div>
    <div class="description">{{ meta.description }}</div>
  </div>
</template>

<script>
  import dayjs from 'dayjs'
  export default {
    props: {
      page: Object
    },
    data() {
      return {
        dayjs
      }
    },
    computed: {
      meta() {
        let obj = {}
        if (this.page.frontmatter.meta) {
          this.page.frontmatter.meta.forEach((meta) => {
            obj[meta.name] = meta.content
          })
        }
        return obj
      }
    }
  }
</script>

<style lang="scss" scoped>
  .blogitem {
    .title {
      display: flex;
      align-items: center;
      height: 40px;
      a {
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
        font-size: 20px;
        flex: 1;
      }
      span {
        text-align: right;
        font-size: 14px;
        width: 80px;
      }
    }
    .description {
      font-size: 14px;
      color: #666;
      line-height: 28px;
      margin-bottom: 30px;
    }
  }

</style>
